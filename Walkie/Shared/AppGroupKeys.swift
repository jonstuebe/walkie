import Foundation

enum AppGroup {
    static let identifier = "group.com.jonstuebe.petwalkie"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }

    enum Key {
        static let petSnapshot = "petSnapshot"
    }
}
