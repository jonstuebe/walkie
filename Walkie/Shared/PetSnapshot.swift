import Foundation

struct PetSnapshot: Codable, Equatable {
    var name: String
    var colorHex: String
    var health: Double
    var stepsToday: Int
    var stepGoal: Int
    var leavesEarned: Int
    var leavesAvailable: Int
    var updatedAt: Date

    var bodyScale: Double { 0.5 + (health * 0.5) }

    // 0...10 half-hearts (5 full hearts max, half-hearts allowed).
    var halfHearts: Int {
        let raw = (health * 10).rounded()
        return max(0, min(10, Int(raw)))
    }

    static let placeholder = PetSnapshot(
        name: "Koa",
        colorHex: "#73BFA6",
        health: 0.85,
        stepsToday: 6_842,
        stepGoal: 10_000,
        leavesEarned: 6,
        leavesAvailable: 4,
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
