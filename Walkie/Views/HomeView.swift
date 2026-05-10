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
            Color(red: 0.04, green: 0.08, blue: 0.06)
                .ignoresSafeArea()

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
            ZStack {
                ForestBackdrop()
                KoalaView(color: pet.color, bodyScale: pet.bodyScale, feedingTrigger: feedTrigger)
                    .animation(.spring, value: pet.bodyScale)
                    .padding(.vertical, 12)
            }
            .frame(maxWidth: .infinity)

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
            .background(Color(red: 0.08, green: 0.10, blue: 0.09))
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
        let canFeed = available > 0 && !isFull

        return HStack(spacing: 16) {
            BambooStockRing(available: available, dimmed: !canFeed)
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(primaryFeedLabel(canFeed: canFeed, isFull: isFull, available: available))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(canFeed ? .white : .white.opacity(0.6))
                if let secondary = secondaryFeedLabel(canFeed: canFeed, isFull: isFull, stepsToNext: stepsToNext) {
                    Text(secondary)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            Spacer(minLength: 8)
            Button(action: { performFeed() }) {
                Text("Feed")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(canFeed ? .black : .white.opacity(0.35))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        Capsule().fill(canFeed ? Color.white : Color.white.opacity(0.08))
                    )
                    .overlay(
                        Capsule().strokeBorder(.white.opacity(canFeed ? 0 : 0.12), lineWidth: 1)
                    )
            }
            .buttonStyle(FeedPillButtonStyle())
            .disabled(!canFeed)
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func primaryFeedLabel(canFeed: Bool, isFull: Bool, available: Int) -> String {
        if isFull { return "Already full" }
        if canFeed { return "\(available) bamboo ready" }
        return "Walk to earn bamboo"
    }

    private func secondaryFeedLabel(canFeed: Bool, isFull: Bool, stepsToNext: Int) -> String? {
        if isFull { return nil }
        if canFeed { return "+10% health · \(formatted(stepsToNext)) to next 🎋" }
        return "\(formatted(stepsToNext)) steps to next 🎋"
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

// Ring shows bamboo banked for today, capped at 10 (one full health refill).
// Center shows the count when > 0, the bamboo glyph as a placeholder otherwise.
private struct BambooStockRing: View {
    var available: Int
    var dimmed: Bool

    private var fill: CGFloat {
        guard available > 0 else { return 0 }
        return CGFloat(min(10, available)) / 10.0
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.12), lineWidth: 5)
            Circle()
                .trim(from: 0, to: fill)
                .stroke(
                    LinearGradient(
                        colors: [Color(red: 0.55, green: 0.85, blue: 0.55), Color(red: 0.30, green: 0.70, blue: 0.40)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5), value: fill)
            if available > 0 {
                Text("\(available)")
                    .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
            } else {
                Text("🎋")
                    .font(.system(size: 22))
                    .opacity(0.55)
            }
        }
        .opacity(dimmed ? 0.55 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: dimmed)
    }
}

private struct FeedPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Forest backdrop

struct ForestBackdrop: View {
    var shadowY: CGFloat = 0.97

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.14, blue: 0.11),
                        Color(red: 0.08, green: 0.26, blue: 0.20),
                        Color(red: 0.06, green: 0.20, blue: 0.14),
                        Color(red: 0.03, green: 0.10, blue: 0.07)
                    ],
                    startPoint: .top, endPoint: .bottom
                )

                RadialGradient(
                    colors: [
                        Color(red: 0.55, green: 0.95, blue: 0.65).opacity(0.18),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.5, y: 0.82),
                    startRadius: 6,
                    endRadius: max(w, h) * 0.55
                )

                BambooStalk(width: 4, height: h * 0.78, segments: 4, color: Self.distantColor)
                    .opacity(0.32).blur(radius: 1.4)
                    .offset(x: -w * 0.30, y: h * 0.05)
                BambooStalk(width: 4, height: h * 0.85, segments: 5, color: Self.distantColor)
                    .opacity(0.30).blur(radius: 1.4)
                    .offset(x: w * 0.22, y: -h * 0.02)
                BambooStalk(width: 4, height: h * 0.62, segments: 3, color: Self.distantColor)
                    .opacity(0.26).blur(radius: 1.6)
                    .offset(x: w * 0.05, y: h * 0.18)

                BambooStalk(width: 7, height: h * 1.10, segments: 6, color: Self.midColor)
                    .opacity(0.6)
                    .offset(x: -w * 0.40, y: 0)
                BambooStalk(width: 7, height: h * 1.05, segments: 5, color: Self.midColor)
                    .opacity(0.6)
                    .offset(x: w * 0.36, y: -h * 0.04)

                BambooStalk(width: 12, height: h * 1.20, segments: 6, color: Self.nearColor)
                    .opacity(0.9)
                    .offset(x: -w * 0.46, y: h * 0.02)
                BambooStalk(width: 11, height: h * 1.18, segments: 6, color: Self.nearColor)
                    .opacity(0.9)
                    .offset(x: w * 0.47, y: 0)

                forestFloor(width: w, height: h)

                Ellipse()
                    .fill(RadialGradient(
                        colors: [Color.black.opacity(0.55), Color.black.opacity(0)],
                        center: .center,
                        startRadius: 2, endRadius: 70
                    ))
                    .frame(width: 140, height: 22)
                    .position(x: w * 0.5, y: h * shadowY)
            }
            .frame(width: w, height: h)
            .clipped()
        }
    }

    private func forestFloor(width w: CGFloat, height h: CGFloat) -> some View {
        let leftY  = h * 1.04
        let rightY = h * 1.06
        let crestY = h * 0.66
        let crestX = w * 0.55
        let floorBottom = h + 200

        return Path { p in
            p.move(to: CGPoint(x: -20, y: leftY))
            p.addQuadCurve(
                to: CGPoint(x: w + 20, y: rightY),
                control: CGPoint(x: crestX, y: crestY)
            )
            p.addLine(to: CGPoint(x: w + 20, y: floorBottom))
            p.addLine(to: CGPoint(x: -20, y: floorBottom))
            p.closeSubpath()
        }
        .fill(LinearGradient(
            colors: [
                Color(red: 0.20, green: 0.42, blue: 0.26),
                Color(red: 0.14, green: 0.32, blue: 0.20),
                Color(red: 0.10, green: 0.24, blue: 0.16)
            ],
            startPoint: .top, endPoint: .bottom
        ))
    }

    private static let distantColor = Color(red: 0.18, green: 0.32, blue: 0.22)
    private static let midColor     = Color(red: 0.30, green: 0.55, blue: 0.34)
    private static let nearColor    = Color(red: 0.38, green: 0.62, blue: 0.40)
}

private struct BambooStalk: View {
    var width: CGFloat
    var height: CGFloat
    var segments: Int
    var color: Color

    var body: some View {
        ZStack {
            Capsule()
                .fill(LinearGradient(
                    colors: [
                        color.opacity(0.55),
                        color,
                        color.opacity(0.65)
                    ],
                    startPoint: .leading, endPoint: .trailing
                ))
                .frame(width: width, height: height)

            Capsule()
                .fill(Color.white.opacity(0.10))
                .frame(width: max(1, width * 0.18), height: height * 0.94)
                .offset(x: -width * 0.22)

            ForEach(1...max(1, segments), id: \.self) { i in
                Capsule()
                    .fill(Color.black.opacity(0.38))
                    .frame(width: width * 1.45, height: 2)
                    .offset(y: -height * 0.5 + height * (CGFloat(i) / CGFloat(segments + 1)))
            }
        }
        .frame(width: width, height: height)
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
