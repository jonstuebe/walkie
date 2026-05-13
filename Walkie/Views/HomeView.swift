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
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial: Bool = false
    @State private var feedTrigger: Int = 0
    @State private var showTutorial: Bool = false

    private var available: Int { manager.bambooAvailable(for: pet, goal: stepGoal) }
    private var isFull: Bool { pet.health >= 1.0 }
    private var canFeed: Bool { available > 0 && !isFull }
    private var progress: Double {
        guard stepGoal > 0 else { return 0 }
        return min(1.0, Double(manager.todaySteps) / Double(stepGoal))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForestBackdrop()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                KoalaView(color: pet.color, bodyScale: pet.bodyScale, feedingTrigger: feedTrigger)
                    .scaleEffect(0.95)
                    .animation(.spring, value: pet.bodyScale)
                Spacer(minLength: 0)
                heroCard
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
            }

            refreshButton
                .padding(.leading, 16)
                .padding(.top, 8)

            tutorialButton
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 16)
                .padding(.top, 8)
        }
        .sheet(isPresented: $showTutorial) {
            TutorialSheet()
        }
        .task {
            // Auto-open the tutorial once after first-install onboarding finishes.
            // Delay past the splash (1.6s + 0.45s fade) so it doesn't race the fade-out.
            guard !hasSeenTutorial else { return }
            try? await Task.sleep(for: .milliseconds(2300))
            hasSeenTutorial = true
            showTutorial = true
        }
    }

    private var tutorialButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showTutorial = true
        } label: {
            Image(systemName: "questionmark")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1))
        }
        .accessibilityLabel("How it works")
    }

    private var refreshButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            Task { await manager.refresh(pet: pet) }
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1))
                .rotationEffect(.degrees(manager.isLoading ? 360 : 0))
                .animation(
                    manager.isLoading
                        ? .linear(duration: 0.9).repeatForever(autoreverses: false)
                        : .default,
                    value: manager.isLoading
                )
        }
        .disabled(manager.isLoading)
        .accessibilityLabel("Refresh")
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(pet.name)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                HeartRow(halfHearts: pet.halfHearts, size: 16, spacing: 3)
                    .accessibilityLabel("Health: \(pet.halfHearts) of 10 half hearts")
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 12, weight: .bold))
                    Text("\(manager.todaySteps)")
                        .font(.system(size: 20, weight: .heavy, design: .rounded).monospacedDigit())
                    Text("/ \(stepGoal)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .foregroundStyle(.white)

                ProgressCapsule(progress: progress)
                    .frame(height: 6)
            }

            HStack(spacing: 12) {
                LeafStrip(available: available, max: 10)
                Spacer(minLength: 4)
                Button(action: performFeed) {
                    Label("Feed", systemImage: "leaf.fill")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(canFeed ? .black : .white.opacity(0.5))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(canFeed
                                ? AnyShapeStyle(LinearGradient(
                                    colors: [Color(red: 0.7, green: 1.0, blue: 0.65), Color(red: 0.5, green: 0.9, blue: 0.55)],
                                    startPoint: .top, endPoint: .bottom))
                                : AnyShapeStyle(Color.white.opacity(0.10))
                            )
                        )
                }
                .buttonStyle(FeedPillButtonStyle())
                .disabled(!canFeed)
            }
        }
        .padding(18)
        .background(.ultraThinMaterial.opacity(0.9))
        .background(Color.black.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func performFeed() {
        guard canFeed else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        manager.feed(pet: pet, goal: stepGoal)
        feedTrigger += 1
        Task { @MainActor in
            // Bite-impact haptic lands when the bamboo reaches the mouth (~0.4s into keyframes).
            try? await Task.sleep(for: .milliseconds(400))
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
}

private struct LeafStrip: View {
    var available: Int
    var max: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<max, id: \.self) { idx in
                Image(systemName: idx < available ? "leaf.fill" : "leaf")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(idx < available ? Color(red: 0.6, green: 0.95, blue: 0.6) : .white.opacity(0.25))
            }
        }
    }
}

private struct ProgressCapsule: View {
    var progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.15))
                Capsule()
                    .fill(LinearGradient(
                        colors: [Color(red: 0.55, green: 0.95, blue: 0.6), Color(red: 0.35, green: 0.75, blue: 0.5)],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(width: Swift.max(6, geo.size.width * progress))
                    .animation(.spring(response: 0.5), value: progress)
            }
        }
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

