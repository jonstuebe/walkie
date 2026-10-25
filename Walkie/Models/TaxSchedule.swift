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

    /// A moment the sweep replays: a tax checkpoint, or the last second of a day
    /// (when leftover leaves are eaten before they reset at midnight).
    enum SweepEvent: Equatable {
        case checkpoint(Date)
        case dayEnd(Date)
    }

    /// Sweep events whose timestamps fall in `(since, now]`, in order.
    static func events(
        since startWindow: Date,
        now: Date,
        wakeMinutes: Int,
        sleepMinutes: Int,
        calendar: Calendar = .current
    ) -> [SweepEvent] {
        var cursorDay = calendar.startOfDay(for: startWindow)
        let endDay = calendar.startOfDay(for: now)

        var events: [SweepEvent] = []
        while cursorDay <= endDay {
            for checkpoint in checkpoints(on: cursorDay, wakeMinutes: wakeMinutes, sleepMinutes: sleepMinutes, calendar: calendar) {
                if checkpoint > startWindow && checkpoint <= now {
                    events.append(.checkpoint(checkpoint))
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursorDay) else { break }
            let dayEnd = next.addingTimeInterval(-1)
            if dayEnd > startWindow && dayEnd <= now {
                events.append(.dayEnd(dayEnd))
            }
            cursorDay = next
        }
        return events
    }

    /// Convenience using the user's configured wake/sleep times.
    static func events(since startWindow: Date, now: Date, calendar: Calendar = .current) -> [SweepEvent] {
        events(since: startWindow, now: now, wakeMinutes: wakeMinutes, sleepMinutes: sleepMinutes, calendar: calendar)
    }

    /// Number of tax checkpoints whose timestamps fall in `(since, now]`.
    static func checkpointsElapsed(
        since startWindow: Date,
        now: Date,
        wakeMinutes: Int,
        sleepMinutes: Int,
        calendar: Calendar = .current
    ) -> Int {
        events(since: startWindow, now: now, wakeMinutes: wakeMinutes, sleepMinutes: sleepMinutes, calendar: calendar)
            .filter { if case .checkpoint = $0 { true } else { false } }
            .count
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
