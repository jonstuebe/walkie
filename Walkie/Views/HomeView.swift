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
    @State private var feedTrigger: Int = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    stepsCard
                    petCard
                    feedCard
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
    }

    private func performFeed() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        manager.feed(pet: pet, goal: stepGoal)
        feedTrigger += 1
        Task { @MainActor in
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

    private var feedCard: some View {
        let available = manager.bambooAvailable(for: pet, goal: stepGoal)
        let isFull = pet.health >= 1.0
        let stepsToNext = BambooLedger.stepsToNextBamboo(steps: manager.todaySteps, goal: stepGoal)
        let stride = BambooLedger.stepsPerBamboo(goal: stepGoal)
        let bambooProgress = Double(stride - stepsToNext) / Double(stride)
        let canFeed = available > 0 && !isFull

        return Button(action: { performFeed() }) {
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    Text("🎋")
                        .font(.title)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(canFeed ? 0.18 : 0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(primaryLabel(canFeed: canFeed, isFull: isFull, available: available))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(canFeed ? .white : .white.opacity(0.5))
                        Text(secondaryLabel(canFeed: canFeed, isFull: isFull, available: available))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    Spacer(minLength: 0)
                    if available > 0 {
                        Text("\(available) 🎋")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.white.opacity(0.18))
                            .clipShape(Capsule())
                    }
                }

                VStack(spacing: 6) {
                    BambooProgressBar(progress: bambooProgress)
                        .frame(height: 6)
                    HStack {
                        Text("Next 🎋")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.45))
                        Spacer()
                        Text("\(formatted(stepsToNext)) steps to go")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
            }
            .padding(20)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(FeedCardButtonStyle())
        .disabled(!canFeed)
    }

    private func primaryLabel(canFeed: Bool, isFull: Bool, available: Int) -> String {
        if canFeed { return "Feed Koala" }
        if isFull { return "Already full" }
        if available == 0 { return "No bamboo yet" }
        return "Feed Koala"
    }

    private func secondaryLabel(canFeed: Bool, isFull: Bool, available: Int) -> String {
        if isFull { return "Health is maxed out" }
        if canFeed { return "+10% health per feed" }
        return "Walk to earn your first bamboo"
    }

    private func formatted(_ n: Int) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: n), number: .decimal)
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

private struct BambooProgressBar: View {
    var progress: Double  // 0...1

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.10))
                Capsule()
                    .fill(LinearGradient(
                        colors: [Color(red: 0.55, green: 0.85, blue: 0.55), Color(red: 0.30, green: 0.70, blue: 0.40)],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(width: max(4, geo.size.width * min(1.0, max(0, progress))))
                    .animation(.spring(response: 0.5), value: progress)
            }
        }
    }
}

private struct FeedCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
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
