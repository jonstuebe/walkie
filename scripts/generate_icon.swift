// Renders Walkie's app icons by driving the in-app KoalaView through
// SwiftUI's ImageRenderer. Produces one icon set per PetColor (one primary
// + alternates) so the user's chosen koala color follows them onto the
// home screen via UIApplication.setAlternateIconName(_:).
//
// Compiled with KoalaView.swift and PetColor.swift via scripts/render-icons.sh.

import SwiftUI
import AppKit

// The view rendered into each icon. Sky-to-grass gradient background with
// bamboo stalks flanking the koala so the focal pet still pops while hinting
// at the in-app forest backdrop.
private struct AppIconArt: View {
    let color: Color

    private static let nearStalk = Color(red: 0.40, green: 0.66, blue: 0.42)
    private static let midStalk  = Color(red: 0.32, green: 0.58, blue: 0.36)
    private static let farStalk  = Color(red: 0.26, green: 0.48, blue: 0.30)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.55, green: 0.82, blue: 0.96),
                    Color(red: 0.70, green: 0.88, blue: 0.68)
                ],
                startPoint: .top, endPoint: .bottom
            )

            // Distant stalks, blurred and tucked behind the koala silhouette.
            IconBambooStalk(width: 28, height: 980, segments: 5, color: Self.farStalk)
                .opacity(0.45).blur(radius: 4)
                .offset(x: -180, y: -10)
            IconBambooStalk(width: 26, height: 920, segments: 5, color: Self.farStalk)
                .opacity(0.40).blur(radius: 4)
                .offset(x: 200, y: 30)

            // Mid stalks just inside the icon edge.
            IconBambooStalk(width: 52, height: 1120, segments: 6, color: Self.midStalk)
                .opacity(0.85)
                .offset(x: -360, y: 0)
            IconBambooStalk(width: 48, height: 1080, segments: 6, color: Self.midStalk)
                .opacity(0.85)
                .offset(x: 370, y: -20)

            // Foreground stalks anchoring the corners.
            IconBambooStalk(width: 78, height: 1200, segments: 6, color: Self.nearStalk)
                .offset(x: -450, y: 30)
            IconBambooStalk(width: 74, height: 1180, segments: 6, color: Self.nearStalk)
                .offset(x: 455, y: 10)

            KoalaView(color: color, bodyScale: 1.0)
                .scaleEffect(3.6)
                .offset(y: 60)
        }
        .frame(width: 1024, height: 1024)
        .clipped()
    }
}

private struct IconBambooStalk: View {
    var width: CGFloat
    var height: CGFloat
    var segments: Int
    var color: Color

    var body: some View {
        ZStack {
            Capsule()
                .fill(LinearGradient(
                    colors: [
                        color.opacity(0.65),
                        color,
                        color.opacity(0.75)
                    ],
                    startPoint: .leading, endPoint: .trailing
                ))
                .frame(width: width, height: height)

            Capsule()
                .fill(Color.white.opacity(0.16))
                .frame(width: max(1, width * 0.18), height: height * 0.94)
                .offset(x: -width * 0.22)

            ForEach(1...max(1, segments), id: \.self) { i in
                Capsule()
                    .fill(Color.black.opacity(0.32))
                    .frame(width: width * 1.45, height: max(2, width * 0.16))
                    .offset(y: -height * 0.5 + height * (CGFloat(i) / CGFloat(segments + 1)))
            }
        }
        .frame(width: width, height: height)
    }
}

@MainActor
private func renderPNG(color: Color, size: Int = 1024) -> Data? {
    let renderer = ImageRenderer(content: AppIconArt(color: color))
    renderer.proposedSize = ProposedViewSize(width: CGFloat(size), height: CGFloat(size))
    renderer.scale = 1.0

    guard let cgImage = renderer.cgImage else { return nil }

    // App Store rejects icons with an alpha channel — flatten to RGB.
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { return nil }
    ctx.interpolationQuality = .high
    ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))

    guard let flat = ctx.makeImage() else { return nil }
    return NSBitmapImageRep(cgImage: flat).representation(using: .png, properties: [:])
}

private let contentsJSON = """
{
  "images" : [
    {
      "filename" : "icon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}

"""

@MainActor
private func writeIconSet(name: String, color: Color, into assetsURL: URL) throws {
    let setURL = assetsURL.appendingPathComponent("\(name).appiconset")
    try FileManager.default.createDirectory(at: setURL, withIntermediateDirectories: true)

    guard let png = renderPNG(color: color) else {
        throw NSError(domain: "icongen", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "render failed: \(name)"])
    }

    try png.write(to: setURL.appendingPathComponent("icon-1024.png"))
    try contentsJSON.write(to: setURL.appendingPathComponent("Contents.json"),
                           atomically: true, encoding: .utf8)
    print("wrote \(name)")
}

@main
struct IconGen {
    @MainActor
    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            FileHandle.standardError.write(Data("usage: walkie-icongen <Assets.xcassets>\n".utf8))
            exit(1)
        }
        let assetsURL = URL(fileURLWithPath: CommandLine.arguments[1])

        // Primary uses gray; setAlternateIconName(nil) reverts to it.
        try writeIconSet(name: "AppIcon", color: PetColor.gray.color, into: assetsURL)

        for petColor in PetColor.allCases where petColor != .gray {
            let alternateName = "AppIcon-\(petColor.rawValue.capitalized)"
            try writeIconSet(name: alternateName, color: petColor.color, into: assetsURL)
        }
    }
}
