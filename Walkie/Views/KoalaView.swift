import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// The koala is a tinted vector illustration (see `Assets.xcassets/Koala-*`).
/// The fur recolors per pet color; the outline, ears, belly and leaves stay
/// constant. Behaviours that still map to a static image are preserved:
/// health-based scale, a feed squash + flying-leaf + sparkle burst, a tap
/// wiggle, and a dimmed grayscale "gone" state.
struct KoalaView: View {
    var color: Color
    var bodyScale: Double  // 0.5 (starving) → 1.0 (thriving)
    var isAlive: Bool = true
    var feedingTrigger: Int = 0
    /// WidgetKit renders a single static snapshot and does not run — or reliably
    /// render — `keyframeAnimator`/`TimelineView` content. Widgets pass
    /// `animated: false` to get a plain, always-visible koala.
    var animated: Bool = true

    // Native footprint kept identical so existing layouts don't shift.
    private static let frameW: CGFloat = 186
    private static let frameH: CGFloat = 244

    // Where the flying leaf and sparkles converge (relative to frame center).
    private static let mouthY: CGFloat = -2

    private var petColor: PetColor { PetColor.nearest(to: color) }
    // Gently shrink a hungry koala without making it tiny.
    private var healthScale: CGFloat { CGFloat(0.86 + 0.14 * bodyScale) }

    @State private var feedStart: Date = .distantPast
    @State private var sparkleActive: Bool = false
    @State private var wiggleScaleX: Double = 1.0
    @State private var wiggleScaleY: Double = 1.0
    @State private var wiggleTask: Task<Void, Never>?

    /// The koala illustration with health scale + grayscale/opacity applied.
    /// Shared by the animated (app) and static (widget) paths.
    private var koalaImage: some View {
        Image(petColor.koalaAsset)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: Self.frameW, height: Self.frameH, alignment: .bottom)
            .scaleEffect(healthScale, anchor: .bottom)
            .grayscale(isAlive ? 0 : 1)
            .opacity(isAlive ? 1 : 0.55)
    }

    var body: some View {
        if animated {
            animatedBody
        } else {
            koalaImage
                .frame(width: Self.frameW, height: Self.frameH, alignment: .bottom)
        }
    }

    private var animatedBody: some View {
        Color.clear
            .frame(width: Self.frameW, height: Self.frameH)
            .keyframeAnimator(initialValue: FeedAnim(), trigger: feedingTrigger) { _, v in
                ZStack(alignment: .bottom) {
                    koalaImage
                        .scaleEffect(x: v.squashX, y: v.squashY, anchor: .bottom)
                        .offset(y: v.hopY)
                        .animation(.spring(response: 0.55, dampingFraction: 0.72), value: bodyScale)

                    if sparkleActive {
                        SparkleBurst(start: feedStart)
                            .frame(width: 220, height: 220)
                            .offset(y: Self.mouthY - 8)
                            .allowsHitTesting(false)
                    }

                    LeafFlight(
                        opacity: v.leafOpacity,
                        scale: v.leafScale,
                        translation: v.leafY
                    )
                    .offset(y: Self.mouthY)
                    .allowsHitTesting(false)
                }
                .frame(width: Self.frameW, height: Self.frameH)
            } keyframes: { _ in
                // Leaf: fly from below to the mouth (0 → 0.4s), then get consumed.
                KeyframeTrack(\.leafY) {
                    LinearKeyframe(140, duration: 0.0)
                    CubicKeyframe(0,   duration: 0.40)
                    LinearKeyframe(0,  duration: 0.60)
                }
                KeyframeTrack(\.leafOpacity) {
                    LinearKeyframe(0, duration: 0.0)
                    LinearKeyframe(1, duration: 0.06)
                    LinearKeyframe(1, duration: 0.34)
                    LinearKeyframe(0, duration: 0.05)
                    LinearKeyframe(0, duration: 0.55)
                }
                KeyframeTrack(\.leafScale) {
                    LinearKeyframe(1.4, duration: 0.0)
                    CubicKeyframe(0.55, duration: 0.40)
                    CubicKeyframe(0.0,  duration: 0.05)
                    LinearKeyframe(0.0, duration: 0.55)
                }

                // Whole-body squash & bounce as the leaf lands — round & happy.
                KeyframeTrack(\.squashX) {
                    LinearKeyframe(1.00, duration: 0.40)
                    SpringKeyframe(1.08, duration: 0.18, spring: .bouncy)
                    SpringKeyframe(0.97, duration: 0.18)
                    SpringKeyframe(1.00, duration: 0.34)
                }
                KeyframeTrack(\.squashY) {
                    LinearKeyframe(1.00, duration: 0.40)
                    SpringKeyframe(0.92, duration: 0.18, spring: .bouncy)
                    SpringKeyframe(1.05, duration: 0.18)
                    SpringKeyframe(1.00, duration: 0.34)
                }
                // A small delighted hop.
                KeyframeTrack(\.hopY) {
                    LinearKeyframe(0.0, duration: 0.40)
                    SpringKeyframe(-9.0, duration: 0.18, spring: .bouncy)
                    SpringKeyframe(0.0, duration: 0.42)
                }
            }
            .scaleEffect(x: wiggleScaleX, y: wiggleScaleY, anchor: .bottom)
            .onTapGesture {
                guard isAlive else { return }
                wiggle()
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

    @MainActor
    private func wiggle() {
        wiggleTask?.cancel()
        wiggleTask = Task { @MainActor in
            withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) {
                wiggleScaleX = 1.10
                wiggleScaleY = 0.90
            }
            try? await Task.sleep(for: .milliseconds(140))
            if Task.isCancelled { return }
            withAnimation(.spring(response: 0.22, dampingFraction: 0.45)) {
                wiggleScaleX = 0.95
                wiggleScaleY = 1.05
            }
            try? await Task.sleep(for: .milliseconds(160))
            if Task.isCancelled { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                wiggleScaleX = 1.0
                wiggleScaleY = 1.0
            }
        }
    }
}

// MARK: - Feed animation values

private struct FeedAnim {
    var leafY: Double = 0
    var leafOpacity: Double = 0
    var leafScale: Double = 1
    var squashX: Double = 1
    var squashY: Double = 1
    var hopY: Double = 0
}

// MARK: - Leaf flight

private struct LeafFlight: View {
    var opacity: Double
    var scale: Double
    var translation: Double  // vertical offset added to mouth position

    var body: some View {
        Text("🍃")
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
    ScrollView(.horizontal) {
        HStack(spacing: 12) {
            ForEach(PetColor.allCases) { c in
                KoalaView(color: c.color, bodyScale: 1.0)
            }
        }
        .padding()
    }
}
