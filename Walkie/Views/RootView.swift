import SwiftUI
import SwiftData

struct RootView: View {
    @Query private var pets: [Pet]
    @State private var showSplash: Bool = true

    var body: some View {
        ZStack {
            if pets.isEmpty {
                OnboardingView()
            } else {
                HomeView()
            }

            if showSplash {
                SplashView(koalaColor: pets.first?.color ?? Color(hex: "#73BFA6"))
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(1600))
            withAnimation(.easeOut(duration: 0.45)) {
                showSplash = false
            }
        }
    }
}
