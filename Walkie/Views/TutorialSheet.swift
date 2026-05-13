import SwiftUI

struct TutorialSheet: View {
    @State private var index: Int = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $index) {
                ForEach(TutorialPage.allCases, id: \.rawValue) { page in
                    pageContent(page).tag(page.rawValue)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 8) {
                ForEach(TutorialPage.allCases, id: \.rawValue) { page in
                    Capsule()
                        .fill(page.rawValue == index ? Color.white : Color.white.opacity(0.25))
                        .frame(width: page.rawValue == index ? 22 : 8, height: 6)
                        .animation(.spring(response: 0.3), value: index)
                }
            }
            .padding(.top, 8)

            Button(action: advance) {
                Text(index == TutorialPage.allCases.count - 1 ? "Got it" : "Next")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Capsule().fill(LinearGradient(
                            colors: [Color(red: 0.7, green: 1.0, blue: 0.65), Color(red: 0.5, green: 0.9, blue: 0.55)],
                            startPoint: .top, endPoint: .bottom))
                    )
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)
            .padding(.bottom, 28)
        }
        .background(TutorialBackdrop().ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(.clear)
    }

    @ViewBuilder
    private func pageContent(_ page: TutorialPage) -> some View {
        VStack(spacing: 22) {
            heroIcon(for: page)
                .frame(height: 90)
            Text(page.title)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(page.body)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .padding(.top, 32)
    }

    @ViewBuilder
    private func heroIcon(for page: TutorialPage) -> some View {
        switch page {
        case .hearts:
            AnimatedHeartRow(targetHalfHearts: 10, size: 30, spacing: 6)
        case .bamboo:
            AnimatedLeafStrip(targetFilled: 10, total: 10)
        }
    }

    private func advance() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if index < TutorialPage.allCases.count - 1 {
            withAnimation(.spring) { index += 1 }
        } else {
            dismiss()
        }
    }
}

private enum TutorialPage: Int, CaseIterable {
    case hearts, bamboo

    var title: String {
        switch self {
        case .hearts: return "Hearts are health"
        case .bamboo: return "Bamboo feeds the koala"
        }
    }

    var body: String {
        switch self {
        case .hearts:
            return "Five hearts, half-hearts allowed. Hit your step goal to gain a full heart. Falling short slowly drains them — zero hearts and your koala is gone."
        case .bamboo:
            return "Each leaf is one bamboo, earned every 10% of your daily goal. Spend them on Feed to add a half-heart at a time. Unspent bamboo resets at midnight."
        }
    }
}

private struct AnimatedHeartRow: View {
    var targetHalfHearts: Int
    var size: CGFloat = 24
    var spacing: CGFloat = 4

    @State private var current: Int = 0

    var body: some View {
        HeartRow(halfHearts: current, size: size, spacing: spacing)
            .onAppear {
                current = 0
                Task {
                    try? await Task.sleep(for: .milliseconds(250))
                    for step in 0...targetHalfHearts {
                        await MainActor.run {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                                current = step
                            }
                        }
                        try? await Task.sleep(for: .milliseconds(120))
                    }
                }
            }
    }
}

private struct AnimatedLeafStrip: View {
    var targetFilled: Int
    var total: Int = 10
    var size: CGFloat = 22

    @State private var current: Int = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { idx in
                Image(systemName: idx < current ? "leaf.fill" : "leaf")
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(idx < current
                                     ? Color(red: 0.6, green: 0.95, blue: 0.6)
                                     : .white.opacity(0.28))
            }
        }
        .onAppear {
            current = 0
            Task {
                try? await Task.sleep(for: .milliseconds(250))
                for step in 0...targetFilled {
                    await MainActor.run {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            current = step
                        }
                    }
                    try? await Task.sleep(for: .milliseconds(90))
                }
            }
        }
    }
}

private struct TutorialBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.18, blue: 0.13),
                    Color(red: 0.03, green: 0.09, blue: 0.07)
                ],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(
                colors: [Color(red: 0.55, green: 0.95, blue: 0.65).opacity(0.10), .clear],
                center: .center, startRadius: 0, endRadius: 240
            )
        }
    }
}

#Preview {
    Color.black
        .sheet(isPresented: .constant(true)) {
            TutorialSheet()
        }
}
