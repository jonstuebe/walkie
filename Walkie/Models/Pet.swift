import SwiftData
import SwiftUI

@Model
final class Pet {
    var name: String
    var colorHex: String
    var birthDate: Date
    var health: Double  // 0.0 (dead) to 1.0 (thriving)
    var isAlive: Bool
    var totalStepsLifetime: Int
    // Bamboo ledger — daily reset; default to .distantPast so existing rows roll over on first read.
    var bambooSpentToday: Int = 0
    var bambooLedgerDate: Date = Date.distantPast
    // Health tax bookkeeping — default to now so existing pets get a fresh start on update.
    var lastTaxAppliedAt: Date = Date()

    init(name: String, colorHex: String) {
        self.name = name
        self.colorHex = colorHex
        self.birthDate = Date()
        self.health = 0.75
        self.isAlive = true
        self.totalStepsLifetime = 0
        self.bambooSpentToday = 0
        self.bambooLedgerDate = Calendar.current.startOfDay(for: Date())
        self.lastTaxAppliedAt = Date()
    }

    var color: Color {
        Color(hex: colorHex)
    }

    // Maps the 0.0–1.0 health scalar onto a 5-heart scale, half-hearts allowed.
    // 10 = 5 full hearts, 1 = half a heart, 0 = empty.
    var halfHearts: Int {
        let raw = (health * 10).rounded()
        return Swift.max(0, Swift.min(10, Int(raw)))
    }

    // Used by background notifications to decide when to ping the user.
    var healthState: HealthState {
        switch halfHearts {
        case 9...10: return .thriving
        case 5...8:  return .happy
        case 1...4:  return .hungry
        default:     return .critical
        }
    }

    var bodyScale: Double {
        // Pet gets skinnier as health drops, ranging 0.5 (skeleton) to 1.0 (chubby)
        0.5 + (health * 0.5)
    }

    enum HealthState {
        case thriving, happy, hungry, critical
    }
}

@Model
final class GraveyardPet {
    var name: String
    var colorHex: String
    var birthDate: Date
    var deathDate: Date
    var totalStepsLifetime: Int
    var daysLived: Int

    init(from pet: Pet) {
        self.name = pet.name
        self.colorHex = pet.colorHex
        self.birthDate = pet.birthDate
        self.deathDate = Date()
        self.totalStepsLifetime = pet.totalStepsLifetime
        self.daysLived = Calendar.current.dateComponents([.day], from: pet.birthDate, to: Date()).day ?? 0
    }

    var color: Color {
        Color(hex: colorHex)
    }
}
