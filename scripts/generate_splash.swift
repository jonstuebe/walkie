// Renders Walkie's launch image: the wordmark "walkie" centered on a solid
// forest-green background. Output lands in Assets.xcassets/Splash.imageset
// and is referenced by UILaunchScreen in Info.plist.

import SwiftUI
import AppKit

private let canvasWidth: CGFloat = 1290
private let canvasHeight: CGFloat = 2796

private let backgroundColor = Color(red: 0.08, green: 0.26, blue: 0.20)

private struct SplashArt: View {
    var body: some View {
        ZStack {
            backgroundColor

            Text("walkie")
                .font(.system(size: 180, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: canvasWidth, height: canvasHeight)
        .clipped()
    }
}

@MainActor
private func renderPNG() -> Data? {
    let renderer = ImageRenderer(content: SplashArt())
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
      "idiom" : "universal",
      "scale" : "3x"
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
private func writeImageSet(name: String, into assetsURL: URL) throws {
    let setURL = assetsURL.appendingPathComponent("\(name).imageset")
    try FileManager.default.createDirectory(at: setURL, withIntermediateDirectories: true)

    guard let png = renderPNG() else {
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

        try writeImageSet(name: "Splash", into: assetsURL)
    }
}
