import UIKit

enum AppIconManager {
    static func sync(toColorHex hex: String) {
        let target = alternateName(for: hex)
        let current = UIApplication.shared.alternateIconName
        guard target != current else { return }
        guard UIApplication.shared.supportsAlternateIcons else { return }
        UIApplication.shared.setAlternateIconName(target) { error in
            if let error {
                print("setAlternateIconName(\(target ?? "nil")) failed: \(error)")
            }
        }
    }

    // Primary icon is gray; passing nil reverts to it.
    private static func alternateName(for hex: String) -> String? {
        guard let petColor = PetColor.allCases.first(where: { $0.hex == hex }),
              petColor != .gray else { return nil }
        return "AppIcon-\(petColor.rawValue.capitalized)"
    }
}
