import SwiftUI

struct SplashView: View {
    var koalaColor: Color = Color(hex: "#73BFA6")

    @State private var koalaScale: CGFloat = 0.6
    @State private var koalaOpacity: Double = 0
    @State private var titleOffset: CGFloat = 18
    @State private var titleOpacity: Double = 0

    var body: some View {
        ZStack {
            ForestBackdrop(shadowY: 0.59)
                .ignoresSafeArea()

            RadialGradient(
                colors: [.black.opacity(0.0), .black.opacity(0.45)],
                center: .center,
                startRadius: 80,
                endRadius: 520
            )
            .ignoresSafeArea()
            .blendMode(.multiply)

            VStack(spacing: 12) {
                KoalaView(color: koalaColor, bodyScale: 1.0)
                    .scaleEffect(koalaScale)
                    .opacity(koalaOpacity)

                Text("walkie")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.45), radius: 8, x: 0, y: 3)
                    .offset(y: titleOffset)
                    .opacity(titleOpacity)
            }
            .padding(.bottom, 24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.65, dampingFraction: 0.7)) {
                koalaScale = 1.0
                koalaOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.55).delay(0.25)) {
                titleOffset = 0
                titleOpacity = 1
            }
        }
    }
}

#Preview {
    SplashView()
}
