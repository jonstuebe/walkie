import SwiftUI

struct HeartRow: View {
    var halfHearts: Int
    var totalHearts: Int = 5
    var size: CGFloat = 14
    var spacing: CGFloat = 2
    var color: Color = Color(red: 1.0, green: 0.42, blue: 0.45)
    var emptyColor: Color = Color.white.opacity(0.5)

    @State private var shakeTrigger: CGFloat = 0

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<totalHearts, id: \.self) { idx in
                heart(for: idx)
                    .font(.system(size: size, weight: .heavy))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: halfHearts)
        .modifier(HeartShake(animatableData: shakeTrigger))
        .onChange(of: halfHearts) { oldValue, newValue in
            if newValue < oldValue {
                withAnimation(.linear(duration: 0.45)) {
                    shakeTrigger += 1
                }
            }
        }
    }

    @ViewBuilder
    private func heart(for index: Int) -> some View {
        let filledHalves = halfHearts - index * 2
        if filledHalves >= 2 {
            Image(systemName: "heart.fill")
                .foregroundStyle(color)
        } else if filledHalves == 1 {
            ZStack {
                Image(systemName: "heart")
                    .foregroundStyle(emptyColor)
                Image(systemName: "heart.fill")
                    .foregroundStyle(color)
                    .mask {
                        HStack(spacing: 0) {
                            Rectangle()
                            Rectangle().opacity(0)
                        }
                    }
            }
        } else {
            Image(systemName: "heart")
                .foregroundStyle(emptyColor)
        }
    }
}

private struct HeartShake: GeometryEffect {
    var amount: CGFloat = 4
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let dx = amount * sin(animatableData * .pi * 2 * shakesPerUnit)
        return ProjectionTransform(CGAffineTransform(translationX: dx, y: 0))
    }
}

#Preview {
    VStack(spacing: 12) {
        ForEach(0...10, id: \.self) { halves in
            HStack(spacing: 12) {
                Text("\(halves)").monospacedDigit().frame(width: 24)
                HeartRow(halfHearts: halves)
            }
        }
    }
    .padding()
    .background(.black)
}
