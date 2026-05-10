import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct KoalaView: View {
    var color: Color
    var bodyScale: Double  // 0.5 (starving) → 1.0 (thriving)
    var isAlive: Bool = true
    var feedingTrigger: Int = 0

    private var bodyW: CGFloat { CGFloat(55 + bodyScale * 65) }
    private var bodyH: CGFloat { CGFloat(50 + bodyScale * 55) }
    private static let headD: CGFloat = 114
    private static let earD:  CGFloat = 50
    private static let eyeD:  CGFloat = 30

    // Mouth y in frame coordinates: head offset (-40) + headD * 0.30
    private static let mouthY: CGFloat = -40 + headD * 0.30

    @State private var feedStart: Date = .distantPast
    @State private var sparkleActive: Bool = false

    var body: some View {
        Color.clear
            .frame(width: 186, height: 244)
            .keyframeAnimator(initialValue: FeedAnim(), trigger: feedingTrigger) { _, v in
                ZStack {
                    ears
                    bodyLayer
                        .scaleEffect(x: v.bodyScaleX, y: v.bodyScaleY, anchor: .center)
                        .offset(y: 52)
                    arms
                    head(mouthOpen: v.mouthOpen, eyeSquint: v.eyeSquint)
                        .scaleEffect(v.headScale, anchor: .center)
                        .offset(y: -40)
                    legs

                    if sparkleActive {
                        SparkleBurst(start: feedStart)
                            .frame(width: 220, height: 220)
                            .offset(y: -40)
                            .allowsHitTesting(false)
                    }

                    BambooFlight(
                        opacity: v.bambooOpacity,
                        scale: v.bambooScale,
                        translation: v.bambooY
                    )
                    .offset(y: Self.mouthY)
                    .allowsHitTesting(false)
                }
                .frame(width: 186, height: 244)
                .grayscale(isAlive ? 0 : 1)
                .opacity(isAlive ? 1 : 0.55)
                .animation(.spring(response: 0.55, dampingFraction: 0.72), value: bodyScale)
            } keyframes: { _ in
                // Bamboo: fly from below to mouth (0 → 0.4s), then get consumed (0.4 → 0.45s)
                KeyframeTrack(\.bambooY) {
                    LinearKeyframe(140, duration: 0.0)
                    CubicKeyframe(0,   duration: 0.40)
                    LinearKeyframe(0,  duration: 0.60)
                }
                KeyframeTrack(\.bambooOpacity) {
                    LinearKeyframe(0, duration: 0.0)
                    LinearKeyframe(1, duration: 0.06)
                    LinearKeyframe(1, duration: 0.34)
                    LinearKeyframe(0, duration: 0.05)
                    LinearKeyframe(0, duration: 0.55)
                }
                KeyframeTrack(\.bambooScale) {
                    LinearKeyframe(1.4, duration: 0.0)
                    CubicKeyframe(0.55, duration: 0.40)
                    CubicKeyframe(0.0,  duration: 0.05)
                    LinearKeyframe(0.0, duration: 0.55)
                }

                // Mouth chews three times after bamboo arrives
                KeyframeTrack(\.mouthOpen) {
                    LinearKeyframe(0.0, duration: 0.40)
                    SpringKeyframe(1.0, duration: 0.10)
                    SpringKeyframe(0.0, duration: 0.10)
                    SpringKeyframe(1.0, duration: 0.10)
                    SpringKeyframe(0.0, duration: 0.10)
                    SpringKeyframe(1.0, duration: 0.10)
                    SpringKeyframe(0.0, duration: 0.20)
                }

                // Head bobs with each chew
                KeyframeTrack(\.headScale) {
                    LinearKeyframe(1.0, duration: 0.40)
                    SpringKeyframe(1.07, duration: 0.15, spring: .bouncy)
                    SpringKeyframe(0.97, duration: 0.15)
                    SpringKeyframe(1.04, duration: 0.15)
                    SpringKeyframe(1.00, duration: 0.25)
                }

                // Body squashes & bounces — round & happy
                KeyframeTrack(\.bodyScaleX) {
                    LinearKeyframe(1.00, duration: 0.40)
                    SpringKeyframe(1.10, duration: 0.18, spring: .bouncy)
                    SpringKeyframe(0.96, duration: 0.18)
                    SpringKeyframe(1.00, duration: 0.34)
                }
                KeyframeTrack(\.bodyScaleY) {
                    LinearKeyframe(1.00, duration: 0.40)
                    SpringKeyframe(0.90, duration: 0.18, spring: .bouncy)
                    SpringKeyframe(1.06, duration: 0.18)
                    SpringKeyframe(1.00, duration: 0.34)
                }

                // Eyes squint with delight while chewing, then open back up
                KeyframeTrack(\.eyeSquint) {
                    LinearKeyframe(1.00, duration: 0.40)
                    CubicKeyframe(0.55, duration: 0.15)
                    LinearKeyframe(0.55, duration: 0.45)
                    CubicKeyframe(1.00, duration: 0.20)
                }
            }
            .onChange(of: feedingTrigger) { _, newValue in
                guard newValue > 0 else { return }
                feedStart = .now
                sparkleActive = true
                let captured = newValue
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(1300))
                    if feedingTrigger == captured {
                        sparkleActive = false
                    }
                }
            }
    }

    // MARK: - Ears

    private var ears: some View {
        HStack(spacing: 28) {
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

            Ellipse()
                .fill(Color(red: 0.90, green: 0.78, blue: 0.75).opacity(0.88))
                .frame(width: d * 0.50, height: d * 0.58)
        }
    }

    // MARK: - Head

    private func head(mouthOpen: Double, eyeSquint: Double) -> some View {
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

            eyes(squint: eyeSquint)
                .offset(y: -d * 0.05)

            nose
                .offset(y: d * 0.17)

            mouth(open: mouthOpen)
                .offset(y: d * 0.30)

            cheeks
                .offset(y: d * 0.16)
        }
    }

    private var mouthCurvature: Double {
        guard isAlive else { return -1 }
        return bodyScale > 0.55 ? 1 : -1
    }

    private func mouth(open: Double) -> some View {
        ZStack {
            KoalaMouth(curvature: mouthCurvature)
                .stroke(Color(white: 0.18),
                        style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                .frame(width: 22, height: 12)
                .opacity(1 - open)

            ZStack {
                Ellipse()
                    .fill(Color(white: 0.10))
                Ellipse()
                    .fill(Color(red: 0.95, green: 0.55, blue: 0.55))
                    .frame(width: 9, height: 5)
                    .offset(y: 2)
            }
            .frame(width: 18 * (0.55 + 0.45 * open), height: max(0, 14 * open))
            .opacity(open)
        }
        .animation(.spring(response: 0.4), value: mouthCurvature)
    }

    // MARK: - Eyes

    private func eyes(squint: Double) -> some View {
        let d = Self.eyeD
        return HStack(spacing: d * 0.75) {
            eyeShape(squint: squint)
            eyeShape(squint: squint)
        }
    }

    private func eyeShape(squint: Double) -> some View {
        let d = Self.eyeD
        return ZStack {
            Circle()
                .fill(.white)
                .frame(width: d, height: d)
                .shadow(color: .black.opacity(0.1), radius: 1.5, x: 0, y: 1)

            if isAlive {
                Circle()
                    .fill(Color(white: 0.08))
                    .frame(width: d * 0.62, height: d * 0.62)

                Circle()
                    .fill(.white)
                    .frame(width: d * 0.21, height: d * 0.21)
                    .offset(x: d * 0.14, y: -d * 0.14)

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
        .scaleEffect(x: 1.0, y: max(0.15, squint), anchor: .center)
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

            Ellipse()
                .fill(.white.opacity(0.20))
                .frame(width: bodyW * 0.56, height: bodyH * 0.66)
                .offset(y: bodyH * 0.07)
        }
    }

    // MARK: - Arms

    private var arms: some View {
        ZStack {
            arm(side: -1)
            arm(side:  1)
        }
    }

    private func arm(side: CGFloat) -> some View {
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

// MARK: - Feed animation values

private struct FeedAnim {
    var bambooY: Double = 0
    var bambooOpacity: Double = 0
    var bambooScale: Double = 1
    var headScale: Double = 1
    var bodyScaleX: Double = 1
    var bodyScaleY: Double = 1
    var mouthOpen: Double = 0
    var eyeSquint: Double = 1
}

// MARK: - Bamboo flight

private struct BambooFlight: View {
    var opacity: Double
    var scale: Double
    var translation: Double  // vertical offset added to mouth position

    var body: some View {
        Text("🎋")
            .font(.system(size: 44))
            .rotationEffect(.degrees(-12))
            .scaleEffect(max(0.0001, scale))
            .opacity(opacity)
            .offset(y: translation)
            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
    }
}

// MARK: - Sparkles

private struct SparkleBurst: View {
    var start: Date

    private static let particleCount: Int = 14
    private static let burstDuration: Double = 1.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
            let elapsed: Double = context.date.timeIntervalSince(start)
            Canvas { ctx, size in
                drawParticles(into: ctx, size: size, elapsed: elapsed)
            }
        }
    }

    private func drawParticles(into ctx: GraphicsContext, size: CGSize, elapsed: Double) {
        let duration = Self.burstDuration
        guard elapsed >= 0, elapsed <= duration else { return }
        let t: Double = elapsed / duration
        let eased: Double = 1 - pow(1 - t, 3)
        let cx: Double = Double(size.width) * 0.5
        let cy: Double = Double(size.height) * 0.5
        let count = Self.particleCount

        for i in 0..<count {
            drawParticle(ctx: ctx, i: i, t: t, eased: eased, cx: cx, cy: cy, total: count)
        }
    }

    private func drawParticle(ctx baseCtx: GraphicsContext, i: Int, t: Double, eased: Double, cx: Double, cy: Double, total: Int) {
        let isHeart: Bool = (i % 3 == 0)
        let baseAngle: Double = Double(i) / Double(total) * (.pi * 2)
        let angle: Double = baseAngle - (.pi / 2)
        let baseR: Double = 24
        let maxR: Double = isHeart ? 95 : 110
        let r: Double = baseR + (maxR - baseR) * eased
        let drift: Double = sin(t * (.pi * 2) + Double(i)) * 4
        let px: Double = cx + cos(angle) * r + drift
        let py: Double = cy + sin(angle) * r - eased * 8
        let alpha: Double = max(0, 1 - t * t)
        let scale: Double = 1.0 - 0.35 * t
        let glyph: String = isHeart ? "❤️" : "✨"
        let baseSize: Double = isHeart ? 18 : 16
        let fontSize: Double = baseSize * scale

        var ctx = baseCtx
        ctx.opacity = alpha
        let resolved = ctx.resolve(
            Text(glyph).font(.system(size: CGFloat(fontSize)))
        )
        ctx.draw(resolved, at: CGPoint(x: px, y: py))
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
        #if canImport(UIKit)
        UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        #elseif canImport(AppKit)
        let ns = NSColor(self).usingColorSpace(.deviceRGB) ?? NSColor.gray
        ns.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        #endif
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

#Preview("Feeding") {
    struct FeedingPreview: View {
        @State private var trigger = 0
        var body: some View {
            VStack(spacing: 24) {
                KoalaView(color: Color(hex: "#B299D9"), bodyScale: 0.9, feedingTrigger: trigger)
                Button("Feed") { trigger += 1 }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
    return FeedingPreview()
}

#Preview("Colors") {
    HStack(spacing: 12) {
        KoalaView(color: Color(hex: "#B299D9"), bodyScale: 1.0)
        KoalaView(color: Color(hex: "#73BFA6"), bodyScale: 1.0)
        KoalaView(color: Color(hex: "#F2B893"), bodyScale: 1.0)
    }
    .padding()
}
