import SwiftUI

struct HeartRow: View {
    var halfHearts: Int
    var totalHearts: Int = 5
    var size: CGFloat = 14
    var spacing: CGFloat = 2
    var color: Color = Color(red: 1.0, green: 0.42, blue: 0.45)

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<totalHearts, id: \.self) { idx in
                heart(for: idx)
                    .font(.system(size: size, weight: .heavy))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: halfHearts)
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
                    .foregroundStyle(color.opacity(0.35))
                Image(systemName: "heart.lefthalf.filled")
                    .foregroundStyle(color)
            }
        } else {
            Image(systemName: "heart")
                .foregroundStyle(color.opacity(0.35))
        }
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
