import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitService.self) private var healthKit
    @Query private var pets: [Pet]
    @State private var petManager: PetManager?
    @State private var tab: Tab = .home

    enum Tab { case home, graveyard, settings }

    var body: some View {
        ZStack {
            PetMeshGradient(color: pets.first?.color ?? Color(red: 0.3, green: 0.2, blue: 0.5))
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 1.2), value: pets.first?.colorHex)

            TabView(selection: $tab) {
                petTab
                    .tabItem { Label("Home", systemImage: "house.fill") }
                    .tag(Tab.home)

                GraveyardView()
                    .tabItem { Label("Graveyard", systemImage: "moon.stars.fill") }
                    .tag(Tab.graveyard)

                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gear") }
                    .tag(Tab.settings)
            }
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        }
        .task {
            let manager = PetManager(modelContext: modelContext, healthKit: healthKit)
            petManager = manager
            if let pet = pets.first {
                await manager.refresh(pet: pet)
            }
        }
    }

    @ViewBuilder
    private var petTab: some View {
        if let pet = pets.first, let manager = petManager {
            PetHomeView(pet: pet, manager: manager)
        }
    }
}

struct PetHomeView: View {
    var pet: Pet
    var manager: PetManager

    @AppStorage("stepGoal") private var stepGoal: Int = 10_000
    @State private var showFeedSheet = false
    @State private var feedTrigger: Int = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    stepsCard
                    petCard
                    interactionSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
            .refreshable {
                await manager.refresh(pet: pet)
            }
            .background(.clear)
            .navigationTitle(pet.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .background(.clear)
        .sheet(isPresented: $showFeedSheet) {
            FeedSheet(pet: pet, manager: manager, stepGoal: stepGoal, onFeed: performFeed)
                .presentationDetents([.medium])
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(28)
        }
    }

    private func performFeed() {
        Task { @MainActor in
            // Wait for sheet dismiss to finish so the user actually sees the koala react.
            try? await Task.sleep(for: .milliseconds(280))
            manager.feed(pet: pet, goal: stepGoal)
            feedTrigger += 1
            // Bite-impact haptic lands when the bamboo reaches the mouth (~0.4s into keyframes).
            try? await Task.sleep(for: .milliseconds(400))
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    private var stepsCard: some View {
        let tier = manager.healthKit.stepTier(for: manager.todaySteps, goal: stepGoal)
        return HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Today's Steps")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                Text("\(manager.todaySteps)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            Spacer(minLength: 0)
            StepProgressRing(steps: manager.todaySteps, goal: stepGoal, color: tierColor(tier))
                .frame(width: 60, height: 60)
                .accessibilityLabel("Step goal progress")
                .accessibilityValue("\(manager.todaySteps) of \(stepGoal) steps")
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var petCard: some View {
        VStack(spacing: 0) {
            KoalaView(color: pet.color, bodyScale: pet.bodyScale, feedingTrigger: feedTrigger)
                .animation(.spring, value: pet.bodyScale)
                .padding(.vertical, 12)

            Divider()
                .background(.white.opacity(0.1))

            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(pet.healthState.color)
                        .frame(width: 8, height: 8)
                        .shadow(color: pet.healthState.color.opacity(0.8), radius: 4)
                    Text(pet.healthState.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
                Spacer()
                HealthBar(health: pet.health)
                    .frame(width: 120, height: 6)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var interactionSection: some View {
        let tier = manager.healthKit.stepTier(for: manager.todaySteps, goal: stepGoal)
        let steps = manager.todaySteps
        let feedThreshold = Int(Double(stepGoal) * 0.30)
        return VStack(spacing: 1) {
            ActionRow(title: "Feed", icon: "🎋", enabled: tier.canFeed, stepsNeeded: max(0, feedThreshold - steps), position: .top) {
                showFeedSheet = true
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func tierColor(_ tier: StepTier) -> Color {
        switch tier {
        case .thriving: return .green
        case .happy: return .yellow
        case .surviving: return .orange
        case .starving: return .red
        }
    }
}

private struct FeedSheet: View {
    var pet: Pet
    var manager: PetManager
    var stepGoal: Int
    var onFeed: () -> Void

    @Environment(\.dismiss) private var dismiss

    private let healthGain = 0.1

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(.white.opacity(0.25))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 24)

            // Food icon
            Text("🎋")
                .font(.system(size: 72))
                .padding(.bottom, 16)

            Text("Feed \(pet.name)")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.bottom, 6)

            Text("Earn bamboo by walking at least \(Int(Double(stepGoal) * 0.30).formatted()) steps a day.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 32)

            // Health preview
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("Current")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                    Text("\(Int(pet.health * 100))%")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)

                Image(systemName: "arrow.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.4))

                VStack(spacing: 4) {
                    Text("After Feeding")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                    Text("\(Int(min(1.0, pet.health + healthGain) * 100))%")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.green)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 24)
            .background(.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 24)
            .padding(.bottom, 28)

            Button {
                dismiss()
                onFeed()
            } label: {
                Text("Feed")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 0)
        }
    }
}

private struct ActionRow: View {
    enum Position { case top, middle, bottom }
    var title: String
    var icon: String
    var enabled: Bool
    var stepsNeeded: Int
    var position: Position
    var action: () -> Void

    private static let stepFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(icon)
                    .font(.title3)
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(enabled ? .white : .white.opacity(0.35))
                Spacer()
                if !enabled && stepsNeeded > 0 {
                    Text("\(Self.stepFormatter.string(from: NSNumber(value: stepsNeeded)) ?? "\(stepsNeeded)") more steps")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.3))
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(enabled ? 0.4 : 0.2))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
        }
        .disabled(!enabled)
    }
}

// MARK: - Shared gradient

struct PetMeshGradient: View {
    var color: Color

    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                [0.0, 0.5], [0.6, 0.4], [1.0, 0.5],
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
            ],
            colors: meshColors(from: color)
        )
    }

    private func meshColors(from color: Color) -> [Color] {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getHue(&h, saturation: &s, brightness: &b, alpha: &a)

        let shifted = (h + 0.06).truncatingRemainder(dividingBy: 1.0)
        let back    = (h - 0.06 + 1.0).truncatingRemainder(dividingBy: 1.0)

        return [
            // top row
            Color(hue: back,    saturation: s * 0.35, brightness: 0.07),
            Color(hue: h,       saturation: s * 0.50, brightness: 0.13),
            Color(hue: shifted, saturation: s * 0.30, brightness: 0.08),
            // middle row
            Color(hue: h,       saturation: s * 0.55, brightness: 0.14),
            Color(hue: h,       saturation: s * 0.70, brightness: 0.24),
            Color(hue: shifted, saturation: s * 0.45, brightness: 0.11),
            // bottom row
            Color(hue: back,    saturation: s * 0.30, brightness: 0.06),
            Color(hue: h,       saturation: s * 0.40, brightness: 0.10),
            Color(hue: shifted, saturation: s * 0.35, brightness: 0.07),
        ]
    }
}

// MARK: - Progress bars

private struct StepProgressRing: View {
    var steps: Int
    var goal: Int
    var color: Color

    private var progress: CGFloat {
        min(1.0, CGFloat(steps) / CGFloat(max(goal, 1)))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.12), lineWidth: 6)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5), value: progress)
            Image(systemName: "figure.walk")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color)
        }
    }
}

private struct HealthBar: View {
    var health: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.12))
                Capsule()
                    .fill(barGradient)
                    .frame(width: max(6, geo.size.width * health))
                    .animation(.spring(response: 0.5), value: health)
            }
        }
    }

    private var barGradient: LinearGradient {
        LinearGradient(colors: [barColor.opacity(0.8), barColor], startPoint: .leading, endPoint: .trailing)
    }

    private var barColor: Color {
        switch health {
        case 0.75...1.0: return .green
        case 0.4..<0.75: return .yellow
        case 0.15..<0.4: return .orange
        default: return .red
        }
    }
}
