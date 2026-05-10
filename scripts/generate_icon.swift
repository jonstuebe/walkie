// Renders Walkie's app icons by driving the in-app KoalaView through
// SwiftUI's ImageRenderer. Produces one icon set per PetColor (one primary
// + alternates) so the user's chosen koala color follows them onto the
// home screen via UIApplication.setAlternateIconName(_:).
//
// Compiled with KoalaView.swift and PetColor.swift via scripts/render-icons.sh.

import SwiftUI
import AppKit

// The view rendered into each icon. Sky-to-grass gradient background so the
// koala's body color stands out regardless of which PetColor was picked.
private struct AppIconArt: View {
    let color: Color

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.55, green: 0.82, blue: 0.96),
                    Color(red: 0.70, green: 0.88, blue: 0.68)
                ],
                startPoint: .top, endPoint: .bottom
            )

            KoalaView(color: color, bodyScale: 1.0)
                .scaleEffect(3.6)
                .offset(y: 60)
        }
        .frame(width: 1024, height: 1024)
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
