import XCTest
@testable import Walkie

final class LeafLedgerTests: XCTestCase {

    func testEarnsOneLeafPerTenPercentOfGoal() {
        XCTAssertEqual(LeafLedger.earned(steps: 10_000, goal: 10_000), 10)
        XCTAssertEqual(LeafLedger.earned(steps: 5_000, goal: 10_000), 5)
        XCTAssertEqual(LeafLedger.earned(steps: 999, goal: 10_000), 0)
    }

    func testEarningKeepsAccruingPastGoal() {
        XCTAssertEqual(LeafLedger.earned(steps: 15_000, goal: 10_000), 15)
    }

    func testZeroGoalEarnsNothing() {
        XCTAssertEqual(LeafLedger.earned(steps: 10_000, goal: 0), 0)
    }

    func testAvailableIsEarnedMinusSpentFlooredAtZero() {
        XCTAssertEqual(LeafLedger.available(steps: 10_000, goal: 10_000, spent: 3), 7)
        XCTAssertEqual(LeafLedger.available(steps: 10_000, goal: 10_000, spent: 12), 0, "never negative")
    }

    func testStepsToNextLeaf() {
        XCTAssertEqual(LeafLedger.stepsToNextLeaf(steps: 0, goal: 10_000), 1_000)
        XCTAssertEqual(LeafLedger.stepsToNextLeaf(steps: 500, goal: 10_000), 500)
    }
}
