// Renders Walkie's splash image by driving the in-app KoalaView through
// SwiftUI's ImageRenderer. Produces a portrait PNG of the koala on the
// bamboo forest backdrop with the "walkie" wordmark — usable as a static
// launch image asset.
//
// Compiled with KoalaView.swift and PetColor.swift via scripts/render-splash.sh.

import SwiftUI
import AppKit

private let canvasWidth: CGFloat = 1290
private let canvasHeight: CGFloat = 2796

private struct SplashArt: View {
    let color: Color

    private static let nearStalk = Color(red: 0.38, green: 0.62, blue: 0.40)
    private static let midStalk  = Color(red: 0.30, green: 0.55, blue: 0.34)
    private static let farStalk  = Color(red: 0.18, green: 0.32, blue: 0.22)

    var body: some View {
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
                    .clear
                ],
                center: UnitPoint(x: 0.5, y: 0.7),
                startRadius: 30,
                endRadius: max(canvasWidth, canvasHeight) * 0.55
            )

            // Distant blurred stalks
            SplashStalk(width: 26, height: canvasHeight * 0.62, segments: 4, color: Self.farStalk)
                .opacity(0.32).blur(radius: 8)
                .offset(x: -canvasWidth * 0.30, y: canvasHeight * 0.05)
            SplashStalk(width: 26, height: canvasHeight * 0.68, segments: 5, color: Self.farStalk)
                .opacity(0.30).blur(radius: 8)
                .offset(x: canvasWidth * 0.22, y: -canvasHeight * 0.02)
            SplashStalk(width: 26, height: canvasHeight * 0.50, segments: 3, color: Self.farStalk)
                .opacity(0.26).blur(radius: 9)
                .offset(x: canvasWidth * 0.05, y: canvasHeight * 0.18)

            // Mid stalks
            SplashStalk(width: 46, height: canvasHeight * 0.92, segments: 6, color: Self.midStalk)
                .opacity(0.6)
                .offset(x: -canvasWidth * 0.40, y: 0)
            SplashStalk(width: 46, height: canvasHeight * 0.88, segments: 5, color: Self.midStalk)
                .opacity(0.6)
                .offset(x: canvasWidth * 0.36, y: -canvasHeight * 0.04)

            // Foreground stalks anchoring the edges
            SplashStalk(width: 78, height: canvasHeight * 1.0, segments: 6, color: Self.nearStalk)
                .opacity(0.92)
                .offset(x: -canvasWidth * 0.46, y: canvasHeight * 0.02)
            SplashStalk(width: 72, height: canvasHeight * 0.98, segments: 6, color: Self.nearStalk)
                .opacity(0.92)
                .offset(x: canvasWidth * 0.47, y: 0)

            // Vignette
            RadialGradient(
                colors: [.black.opacity(0.0), .black.opacity(0.45)],
                center: .center,
                startRadius: canvasWidth * 0.18,
                endRadius: canvasWidth * 0.95
            )
            .blendMode(.multiply)

            VStack(spacing: 28) {
                KoalaView(color: color, bodyScale: 1.0)
                    .scaleEffect(3.6)
                    .frame(height: 900)

                Text("walkie")
                    .font(.system(size: 220, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.45), radius: 24, x: 0, y: 10)
            }
            .offset(y: -canvasHeight * 0.02)
        }
        .frame(width: canvasWidth, height: canvasHeight)
        .clipped()
    }
}

private struct SplashStalk: View {
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
                    .frame(width: width * 1.45, height: max(2, width * 0.16))
                    .offset(y: -height * 0.5 + height * (CGFloat(i) / CGFloat(segments + 1)))
            }
        }
        .frame(width: width, height: height)
    }
}

@MainActor
private func renderPNG(color: Color) -> Data? {
    let renderer = ImageRenderer(content: SplashArt(color: color))
    renderer.proposedSize = ProposedViewSize(width: canvasWidth, height: canvasHeight)
    renderer.scale = 1.0

    guard let cgImage = renderer.cgImage else { return nil }

    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: Int(canvasWidth),
        height: Int(canvasHeight),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { return nil }
    ctx.interpolationQuality = .high
    ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))

    guard let flat = ctx.makeImage() else { return nil }
    return NSBitmapImageRep(cgImage: flat).representation(using: .png, properties: [:])
}

private let contentsJSON = """
{
  "images" : [
    {
      "filename" : "splash.png",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "preserves-vector-representation" : false
  }
}

"""

@MainActor
private func writeImageSet(name: String, color: Color, into assetsURL: URL) throws {
    let setURL = assetsURL.appendingPathComponent("\(name).imageset")
    try FileManager.default.createDirectory(at: setURL, withIntermediateDirectories: true)

    guard let png = renderPNG(color: color) else {
        throw NSError(domain: "splashgen", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "render failed: \(name)"])
    }

    try png.write(to: setURL.appendingPathComponent("splash.png"))
    try contentsJSON.write(to: setURL.appendingPathComponent("Contents.json"),
                           atomically: true, encoding: .utf8)
    print("wrote \(name)")
}

@main
struct SplashGen {
    @MainActor
    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            FileHandle.standardError.write(Data("usage: walkie-splashgen <Assets.xcassets>\n".utf8))
            exit(1)
        }
        let assetsURL = URL(fileURLWithPath: CommandLine.arguments[1])

        try writeImageSet(name: "Splash", color: PetColor.gray.color, into: assetsURL)
    }
}
