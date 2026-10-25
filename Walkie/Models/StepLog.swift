import Foundation

/// Steps bucketed over a window of time, so the tax sweep can ask "how many
/// steps had been walked that day by time t?" when replaying past checkpoints.
/// Pure value — built from HealthKit in the app, by hand in tests.
struct StepLog: Sendable {
    struct Bucket: Sendable {
        let start: Date
        let steps: Double
    }

    let buckets: [Bucket]

    /// No step history: past checkpoints earn nothing, so nothing is auto-eaten.
    static let empty = StepLog(buckets: [])

    /// Steps walked from the start of `instant`'s day up to `instant`. A bucket
    /// counts once it has started, so this can run a bucket's width ahead.
    func stepsWalked(by instant: Date, calendar: Calendar = .current) -> Int {
        let dayStart = calendar.startOfDay(for: instant)
        let total = buckets
            .filter { $0.start >= dayStart && $0.start < instant }
            .reduce(0) { $0 + $1.steps }
        return Int(total)
    }
}
