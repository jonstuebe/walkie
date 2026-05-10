import SwiftData
import SwiftUI

@Model
final class Pet {
    var name: String
    var colorHex: String
    var birthDate: Date
    var health: Double  // 0.0 (dead) to 1.0 (thriving)
    var lastCheckedDate: Date
    var isAlive: Bool
    var totalStepsLifetime: Int
    // Bamboo ledger — daily reset; default to .distantPast so existing rows roll over on first read.
    var bambooSpentToday: Int = 0
    var bambooLedgerDate: Date = Date.distantPast

    init(name: String, colorHex: String) {
        self.name = name
        self.colorHex = colorHex
        self.birthDate = Date()
        self.health = 0.75
        self.lastCheckedDate = Calendar.current.startOfDay(for: Date())
        self.isAlive = true
        self.totalStepsLifetime = 0
        self.bambooSpentToday = 0
        self.bambooLedgerDate = Calendar.current.startOfDay(for: Date())
    }

    var color: Color {
        Color(hex: colorHex)
    }

    var healthState: HealthState {
        switch health {
        case 0.75...1.0: return .thriving
        case 0.4..<0.75: return .happy
        case 0.15..<0.4: return .hungry
        default: return .critical
        }
    }

    var bodyScale: Double {
        // Pet gets skinnier as health drops, ranging 0.5 (skeleton) to 1.0 (chubby)
        0.5 + (health * 0.5)
    }

    enum HealthState {
        case thriving, happy, hungry, critical

        var label: String {
            switch self {
            case .thriving: return "Thriving"
            case .happy: return "Happy"
            case .hungry: return "Hungry"
            case .critical: return "Critical"
            }
        }

        var color: Color {
            switch self {
            case .thriving: return .green
            case .happy: return .yellow
            case .hungry: return .orange
            case .critical: return .red
            }
        }
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
