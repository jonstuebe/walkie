import Foundation

struct PetSnapshot: Codable, Equatable {
    var name: String
    var colorHex: String
    var health: Double
    var stepsToday: Int
    var stepGoal: Int
    var bambooEarned: Int
    var bambooAvailable: Int
    var updatedAt: Date

    var bodyScale: Double { 0.5 + (health * 0.5) }

    var healthLabel: String {
        switch health {
        case 0.75...1.0: return "Thriving"
        case 0.4..<0.75: return "Happy"
        case 0.15..<0.4: return "Hungry"
        default: return "Critical"
        }
    }

    static let placeholder = PetSnapshot(
        name: "Koa",
        colorHex: "#73BFA6",
        health: 0.85,
        stepsToday: 6_842,
        stepGoal: 10_000,
        bambooEarned: 6,
        bambooAvailable: 4,
        updatedAt: Date()
    )

    static func load() -> PetSnapshot? {
        guard let data = AppGroup.defaults.data(forKey: AppGroup.Key.petSnapshot) else { return nil }
        return try? JSONDecoder().decode(PetSnapshot.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        AppGroup.defaults.set(data, forKey: AppGroup.Key.petSnapshot)
    }

    static func clear() {
        AppGroup.defaults.removeObject(forKey: AppGroup.Key.petSnapshot)
    }
}
