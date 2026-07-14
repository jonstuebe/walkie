import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum PetColor: String, CaseIterable, Identifiable {
    case gray, brown, lavender, mint, peach, slate, sand, pink

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .gray: return Color(red: 0.6, green: 0.6, blue: 0.62)
        case .brown: return Color(red: 0.6, green: 0.42, blue: 0.28)
        case .lavender: return Color(red: 0.7, green: 0.6, blue: 0.85)
        case .mint: return Color(red: 0.45, green: 0.75, blue: 0.65)
        case .peach: return Color(red: 0.95, green: 0.72, blue: 0.58)
        case .slate: return Color(red: 0.44, green: 0.54, blue: 0.64)
        case .sand: return Color(red: 0.85, green: 0.75, blue: 0.55)
        case .pink: return Color(red: 0.9, green: 0.6, blue: 0.72)
        }
    }

    var hex: String {
        switch self {
        case .gray: return "#999A9E"
        case .brown: return "#996B47"
        case .lavender: return "#B299D9"
        case .mint: return "#73BFA6"
        case .peach: return "#F2B893"
        case .slate: return "#708AA3"
        case .sand: return "#D9BF8C"
        case .pink: return "#E699B8"
        }
    }

    /// Asset-catalog image name for the tinted koala illustration.
    var koalaAsset: String { "Koala-\(rawValue)" }

    /// Maps an arbitrary color back to the nearest palette entry. Pet colors
    /// always originate from `hex`, so this resolves exactly for real pets and
    /// degrades gracefully for ad-hoc colors (e.g. `.gray` in previews).
    static func nearest(to color: Color) -> PetColor {
        let target = color.rgbComponents
        return allCases.min(by: { a, b in
            Color(hex: a.hex).rgbComponents.distance(to: target)
                < Color(hex: b.hex).rgbComponents.distance(to: target)
        }) ?? .gray
    }
}

struct RGB {
    var r: Double, g: Double, b: Double
    func distance(to o: RGB) -> Double {
        let dr = r - o.r, dg = g - o.g, db = b - o.b
        return dr * dr + dg * dg + db * db
    }
}

extension Color {
    var rgbComponents: RGB {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return RGB(r: Double(r), g: Double(g), b: Double(b))
        #else
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? .gray
        return RGB(r: Double(ns.redComponent), g: Double(ns.greenComponent), b: Double(ns.blueComponent))
        #endif
    }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 0.6; g = 0.6; b = 0.62
        }
        self.init(red: r, green: g, blue: b)
    }
}
