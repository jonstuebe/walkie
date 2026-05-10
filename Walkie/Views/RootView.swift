import SwiftUI
import SwiftData

struct RootView: View {
    @Query private var pets: [Pet]

    var body: some View {
        if pets.isEmpty {
            OnboardingView()
        } else {
            HomeView()
        }
    }
}
