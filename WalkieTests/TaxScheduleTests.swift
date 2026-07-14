import XCTest
@testable import Walkie

final class TaxScheduleTests: XCTestCase {
    private let cal = Calendar(identifier: .gregorian)

    func testTenCheckpointsPerDay() {
        let day = Date()
        let checkpoints = TaxSchedule.checkpoints(on: day, wakeMinutes: 7 * 60, sleepMinutes: 22 * 60, calendar: cal)
        XCTAssertEqual(checkpoints.count, 10)
    }

    func testLastCheckpointLandsAtSleepTime() {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 7; comps.day = 14
        let day = cal.date(from: comps)!
        let checkpoints = TaxSchedule.checkpoints(on: day, wakeMinutes: 7 * 60, sleepMinutes: 22 * 60, calendar: cal)

        let expectedSleep = cal.startOfDay(for: day).addingTimeInterval(Double(22 * 60) * 60)
        XCTAssertEqual(checkpoints.last!.timeIntervalSince1970, expectedSleep.timeIntervalSince1970, accuracy: 1)
    }

    func testNoCheckpointsWhenWindowIsEmpty() {
        let checkpoints = TaxSchedule.checkpoints(on: Date(), wakeMinutes: 22 * 60, sleepMinutes: 7 * 60, calendar: cal)
        XCTAssertTrue(checkpoints.isEmpty)
    }

    func testElapsedCountsCheckpointsInWindow() {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 7; comps.day = 14
        let day = cal.date(from: comps)!
        let start = cal.startOfDay(for: day) // before the first checkpoint
        let end = cal.startOfDay(for: day).addingTimeInterval(24 * 3600) // whole day

        let count = TaxSchedule.checkpointsElapsed(
            since: start, now: end,
            wakeMinutes: 7 * 60, sleepMinutes: 22 * 60, calendar: cal
        )
        XCTAssertEqual(count, 10, "a full day passes all ten checkpoints")
    }

    func testElapsedIsHalfOpenOnTheStart() {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 7; comps.day = 14
        let day = cal.date(from: comps)!
        let checkpoints = TaxSchedule.checkpoints(on: day, wakeMinutes: 7 * 60, sleepMinutes: 22 * 60, calendar: cal)
        let first = checkpoints[0]

        // Starting exactly on the first checkpoint must not re-count it.
        let count = TaxSchedule.checkpointsElapsed(
            since: first, now: checkpoints[1],
            wakeMinutes: 7 * 60, sleepMinutes: 22 * 60, calendar: cal
        )
        XCTAssertEqual(count, 1)
    }
}
