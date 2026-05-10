import SwiftUI
import UIKit

struct KoalaView: View {
    var color: Color
    var bodyScale: Double  // 0.5 (starving) → 1.0 (thriving)
    var isAlive: Bool = true

    private var bodyW: CGFloat { CGFloat(55 + bodyScale * 65) }
    private var bodyH: CGFloat { CGFloat(50 + bodyScale * 55) }
    private static let headD: CGFloat = 114
    private static let earD:  CGFloat = 50
    private static let eyeD:  CGFloat = 30

    var body: some View {
        ZStack {
            ears
            bodyLayer
            arms
            head
            legs
        }
        .frame(width: 186, height: 244)
        .grayscale(isAlive ? 0 : 1)
        .opacity(isAlive ? 1 : 0.55)
        .animation(.spring(response: 0.55, dampingFraction: 0.72), value: bodyScale)
    }

    // MARK: - Ears

    private var ears: some View {
        let d = Self.earD
        return HStack(spacing: 28) {
            earShape
            earShape
        }
        .offset(y: -72)
    }

    private var earShape: some View {
        let d = Self.earD
        return ZStack {
            Circle()
                .fill(RadialGradient(
                    gradient: Gradient(colors: [color.brightened(0.18), color]),
                    center: .init(x: 0.38, y: 0.3),
                    startRadius: 1, endRadius: d * 0.55
                ))
                .frame(width: d, height: d)
                .shadow(color: .black.opacity(0.14), radius: 3, x: 0, y: 2)

            // Inner ear fur — pinkish-cream
            Ellipse()
                .fill(Color(red: 0.90, green: 0.78, blue: 0.75).opacity(0.88))
                .frame(width: d * 0.50, height: d * 0.58)
        }
    }

    // MARK: - Head

    private var head: some View {
        let d = Self.headD
        return ZStack {
            Circle()
                .fill(RadialGradient(
                    gradient: Gradient(colors: [color.brightened(0.2), color]),
                    center: .init(x: 0.36, y: 0.28),
                    startRadius: 2, endRadius: d * 0.6
                ))
                .frame(width: d, height: d)
                .shadow(color: .black.opacity(0.18), radius: 7, x: 0, y: 3)

            eyes
                .offset(y: -d * 0.05)

            nose
                .offset(y: d * 0.17)

            KoalaMouth(curvature: mouthCurvature)
                .stroke(Color(white: 0.18),
                        style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                .frame(width: 22, height: 12)
                .offset(y: d * 0.30)
                .animation(.spring(response: 0.4), value: mouthCurvature)

            cheeks
                .offset(y: d * 0.16)
        }
        .offset(y: -40)
    }

    private var mouthCurvature: Double {
        guard isAlive else { return -1 }
        return bodyScale > 0.55 ? 1 : -1
    }

    // MARK: - Eyes

    private var eyes: some View {
        let d = Self.eyeD
        return HStack(spacing: d * 0.75) {
            eyeShape
            eyeShape
        }
    }

    private var eyeShape: some View {
        let d = Self.eyeD
        return ZStack {
            // Sclera
            Circle()
                .fill(.white)
                .frame(width: d, height: d)
                .shadow(color: .black.opacity(0.1), radius: 1.5, x: 0, y: 1)

            if isAlive {
                // Iris
                Circle()
                    .fill(Color(white: 0.08))
                    .frame(width: d * 0.62, height: d * 0.62)

                // Specular highlight
                Circle()
                    .fill(.white)
                    .frame(width: d * 0.21, height: d * 0.21)
                    .offset(x: d * 0.14, y: -d * 0.14)

                // Second tiny highlight
                Circle()
                    .fill(.white.opacity(0.5))
                    .frame(width: d * 0.1, height: d * 0.1)
                    .offset(x: -d * 0.16, y: d * 0.12)
            } else {
                Text("×")
                    .font(.system(size: d * 0.68, weight: .black, design: .rounded))
                    .foregroundStyle(Color(white: 0.18))
            }
        }
    }

    // MARK: - Nose

    private var nose: some View {
        ZStack {
            Ellipse()
                .fill(RadialGradient(
                    gradient: Gradient(colors: [Color(white: 0.30), Color(white: 0.10)]),
                    center: .init(x: 0.38, y: 0.32),
                    startRadius: 0, endRadius: 15
                ))
                .frame(width: 32, height: 22)
                .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)

            // Sheen
            Ellipse()
                .fill(.white.opacity(0.22))
                .frame(width: 10, height: 6)
                .offset(x: -5, y: -3.5)
        }
    }

    // MARK: - Cheeks

    @ViewBuilder
    private var cheeks: some View {
        if bodyScale > 0.5 && isAlive {
            let opacity = min(1, (bodyScale - 0.5) * 2) * 0.28
            HStack(spacing: Self.eyeD * 2.6) {
                Ellipse()
                    .fill(Color.pink.opacity(opacity))
                    .frame(width: 20, height: 13)
                Ellipse()
                    .fill(Color.pink.opacity(opacity))
                    .frame(width: 20, height: 13)
            }
        }
    }

    // MARK: - Body

    private var bodyLayer: some View {
        ZStack {
            Ellipse()
                .fill(RadialGradient(
                    gradient: Gradient(colors: [color.brightened(0.14), color]),
                    center: .init(x: 0.36, y: 0.28),
                    startRadius: 2,
                    endRadius: max(bodyW, bodyH) * 0.65
                ))
                .frame(width: bodyW, height: bodyH)
                .shadow(color: .black.opacity(0.12), radius: 5, x: 0, y: 3)

            // Belly highlight
            Ellipse()
                .fill(.white.opacity(0.20))
                .frame(width: bodyW * 0.56, height: bodyH * 0.66)
                .offset(y: bodyH * 0.07)
        }
        .offset(y: 52)
    }

    // MARK: - Arms

    private var arms: some View {
        ZStack {
            arm(side: -1)
            arm(side:  1)
        }
    }

    private func arm(side: CGFloat) -> some View {
        // Anchor rotation near the top so the shoulder stays planted against
        // the body while the forearm swings naturally outward.
        RoundedRectangle(cornerRadius: 14)
            .fill(LinearGradient(
                colors: [color.brightened(0.10), color.brightened(-0.04)],
                startPoint: .top, endPoint: .bottom
            ))
            .frame(width: 28, height: bodyH * 0.46)
            .rotationEffect(
                .degrees(Double(side) * 26),
                anchor: UnitPoint(x: 0.5, y: 0.08)
            )
            // x: centre arm at body edge so it overlaps naturally
            // y: shoulder sits at upper quarter of body
            .offset(x: side * (bodyW * 0.40), y: 52 - bodyH * 0.20)
    }

    // MARK: - Legs

    private var legs: some View {
        ZStack {
            leg(side: -1)
            leg(side:  1)
        }
    }

    private func leg(side: CGFloat) -> some View {
        // Short, wide, very round stumps that emerge from the body bottom
        RoundedRectangle(cornerRadius: 16)
            .fill(LinearGradient(
                colors: [color.brightened(0.06), color.brightened(-0.06)],
                startPoint: .top, endPoint: .bottom
            ))
            .frame(width: 34, height: bodyH * 0.26)
            .rotationEffect(.degrees(Double(side) * 10))
            .offset(x: side * bodyW * 0.16, y: 52 + bodyH * 0.46)
    }
}

// MARK: - Mouth Shape

private struct KoalaMouth: Shape {
    var curvature: Double  // +1 = smile, -1 = frown

    var animatableData: Double {
        get { curvature }
        set { curvature = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control: CGPoint(x: rect.midX, y: rect.midY + CGFloat(curvature) * rect.height * 0.55)
        )
        return p
    }
}

// MARK: - Color helpers

extension Color {
    func brightened(_ amount: Double) -> Color {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(
            hue: Double(h),
            saturation: Double(max(0, s - CGFloat(amount) * 0.08)),
            brightness: Double(min(1, b + CGFloat(amount))),
            opacity: Double(a)
        )
    }
}

// MARK: - Preview

#Preview("Health states") {
    HStack(spacing: 12) {
        VStack {
            KoalaView(color: Color(hex: "#999A9E"), bodyScale: 1.0)
            Text("Thriving").font(.caption2)
        }
        VStack {
            KoalaView(color: Color(hex: "#999A9E"), bodyScale: 0.65)
            Text("Hungry").font(.caption2)
        }
        VStack {
            KoalaView(color: Color(hex: "#999A9E"), bodyScale: 0.5, isAlive: false)
            Text("Gone").font(.caption2)
        }
    }
    .padding()
}

#Preview("Colors") {
    HStack(spacing: 12) {
        KoalaView(color: Color(hex: "#B299D9"), bodyScale: 1.0)
        KoalaView(color: Color(hex: "#73BFA6"), bodyScale: 1.0)
        KoalaView(color: Color(hex: "#F2B893"), bodyScale: 1.0)
    }
    .padding()
}
