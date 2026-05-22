import Foundation

extension Pet {
    static let taxKeyWake = "wakeMinutesFromMidnight"
    static let taxKeySleep = "sleepMinutesFromMidnight"
    static let taxDefaultWake = 7 * 60     // 7:00 AM
    static let taxDefaultSleep = 22 * 60   // 10:00 PM
    static let taxCheckpointCount = 10
    static let taxPerCheckpoint: Double = 0.05  // quarter-heart per tick

    /// Minutes-from-midnight for the user's wake time.
    static var wakeMinutes: Int {
        let raw = UserDefaults.standard.object(forKey: taxKeyWake) as? Int
        return raw ?? taxDefaultWake
    }

    /// Minutes-from-midnight for the user's sleep time.
    static var sleepMinutes: Int {
        let raw = UserDefaults.standard.object(forKey: taxKeySleep) as? Int
        return raw ?? taxDefaultSleep
    }

    /// 10 evenly-spaced checkpoints between wake and sleep on the given day.
    /// The last checkpoint lands exactly at sleep time.
    static func taxCheckpoints(on day: Date, calendar: Calendar = .current) -> [Date] {
        let dayStart = calendar.startOfDay(for: day)
        let span = sleepMinutes - wakeMinutes
        guard span > 0 else { return [] }
        let segment = Double(span) / Double(taxCheckpointCount)
        return (1...taxCheckpointCount).map { i in
            let offsetMinutes = Double(wakeMinutes) + segment * Double(i)
            return dayStart.addingTimeInterval(offsetMinutes * 60)
        }
    }

    /// Applies any half-heart taxes whose checkpoint timestamps fall between
    /// `lastTaxAppliedAt` and `now`. Returns true if the pet's health has
    /// dropped to zero or below, so the caller can run its kill/snapshot flow.
    @discardableResult
    func applyMissedTaxes(now: Date = Date()) -> Bool {
        let calendar = Calendar.current
        let startWindow = lastTaxAppliedAt
        var cursorDay = calendar.startOfDay(for: startWindow)
        let endDay = calendar.startOfDay(for: now)

        var taxesApplied = 0
        while cursorDay <= endDay {
            for checkpoint in Pet.taxCheckpoints(on: cursorDay, calendar: calendar) {
                if checkpoint > startWindow && checkpoint <= now {
                    taxesApplied += 1
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursorDay) else { break }
            cursorDay = next
        }

        if taxesApplied > 0 {
            health = max(0, health - Pet.taxPerCheckpoint * Double(taxesApplied))
        }
        lastTaxAppliedAt = now
        return health <= 0
    }
}
