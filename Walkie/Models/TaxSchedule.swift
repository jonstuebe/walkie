import Foundation

/// Pure health-tax math: where the daily checkpoints fall and how many have
/// elapsed over a window. No SwiftData, no mutation — unit-testable in isolation.
/// `PetLifecycle` applies the result; this type only computes it.
enum TaxSchedule {
    static let taxKeyWake = "wakeMinutesFromMidnight"
    static let taxKeySleep = "sleepMinutesFromMidnight"
    static let taxDefaultWake = 7 * 60     // 7:00 AM
    static let taxDefaultSleep = 22 * 60   // 10:00 PM
    static let checkpointCount = 10
    static let taxPerCheckpoint: Double = 0.05  // quarter-heart per tick

    /// Minutes-from-midnight for the user's wake time (falls back to the default).
    static var wakeMinutes: Int {
        UserDefaults.standard.object(forKey: taxKeyWake) as? Int ?? taxDefaultWake
    }

    /// Minutes-from-midnight for the user's sleep time (falls back to the default).
    static var sleepMinutes: Int {
        UserDefaults.standard.object(forKey: taxKeySleep) as? Int ?? taxDefaultSleep
    }

    /// 10 evenly-spaced checkpoints between wake and sleep on the given day.
    /// The last checkpoint lands exactly at sleep time.
    static func checkpoints(
        on day: Date,
        wakeMinutes: Int,
        sleepMinutes: Int,
        calendar: Calendar = .current
    ) -> [Date] {
        let dayStart = calendar.startOfDay(for: day)
        let span = sleepMinutes - wakeMinutes
        guard span > 0 else { return [] }
        let segment = Double(span) / Double(checkpointCount)
        return (1...checkpointCount).map { i in
            let offsetMinutes = Double(wakeMinutes) + segment * Double(i)
            return dayStart.addingTimeInterval(offsetMinutes * 60)
        }
    }

    /// Number of tax checkpoints whose timestamps fall in `(since, now]`.
    static func checkpointsElapsed(
        since startWindow: Date,
        now: Date,
        wakeMinutes: Int,
        sleepMinutes: Int,
        calendar: Calendar = .current
    ) -> Int {
        var cursorDay = calendar.startOfDay(for: startWindow)
        let endDay = calendar.startOfDay(for: now)

        var count = 0
        while cursorDay <= endDay {
            for checkpoint in checkpoints(on: cursorDay, wakeMinutes: wakeMinutes, sleepMinutes: sleepMinutes, calendar: calendar) {
                if checkpoint > startWindow && checkpoint <= now {
                    count += 1
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursorDay) else { break }
            cursorDay = next
        }
        return count
    }

    /// Convenience using the user's configured wake/sleep times.
    static func checkpointsElapsed(since startWindow: Date, now: Date, calendar: Calendar = .current) -> Int {
        checkpointsElapsed(
            since: startWindow,
            now: now,
            wakeMinutes: wakeMinutes,
            sleepMinutes: sleepMinutes,
            calendar: calendar
        )
    }
}
