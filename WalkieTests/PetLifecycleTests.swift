import XCTest
import SwiftData
@testable import Walkie

final class PetLifecycleTests: XCTestCase {

    // Fixed wake/sleep so tax checkpoints are deterministic regardless of any
    // ambient UserDefaults on the host.
    override func setUp() {
        super.setUp()
        UserDefaults.standard.set(7 * 60, forKey: TaxSchedule.taxKeyWake)
        UserDefaults.standard.set(22 * 60, forKey: TaxSchedule.taxKeySleep)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: TaxSchedule.taxKeyWake)
        UserDefaults.standard.removeObject(forKey: TaxSchedule.taxKeySleep)
        super.tearDown()
    }

    private func makeLifecycle() throws -> (PetLifecycle, ModelContainer, SpyEffects) {
        let container = try ModelContainer(
            for: Pet.self, GraveyardPet.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let lifecycle = PetLifecycle(modelContainer: container)
        let spy = SpyEffects()
        return (lifecycle, container, spy)
    }

    private func graveCount(_ container: ModelContainer) throws -> Int {
        let ctx = ModelContext(container)
        return try ctx.fetchCount(FetchDescriptor<GraveyardPet>())
    }

    private func petCount(_ container: ModelContainer) throws -> Int {
        let ctx = ModelContext(container)
        return try ctx.fetchCount(FetchDescriptor<Pet>())
    }

    // Ten days ahead is enough tax checkpoints (100 at 10/day) to drain any
    // starting health to zero regardless of the exact schedule.
    private var farFuture: Date { Date().addingTimeInterval(10 * 86_400) }

    // MARK: - The original bug

    func testDeathInsertsExactlyOneGraveAndDeletesPet() async throws {
        let (lifecycle, container, spy) = try makeLifecycle()
        await lifecycle.use(spy)
        await lifecycle.hatch(name: "Koa", colorHex: "#73BFA6")

        let outcome = await lifecycle.applyElapsed(now: farFuture, steps: 0, goal: 10_000)

        XCTAssertEqual(outcome, .died)
        XCTAssertEqual(try graveCount(container), 1, "exactly one grave")
        XCTAssertEqual(try petCount(container), 0, "live pet deleted")
        XCTAssertEqual(spy.died, 1, "death notified once")
        XCTAssertEqual(spy.snapshotClears, 1)
    }

    // MARK: - Idempotency / the gate

    func testSecondSweepOnDeadPetDoesNothing() async throws {
        let (lifecycle, container, spy) = try makeLifecycle()
        await lifecycle.use(spy)
        await lifecycle.hatch(name: "Koa", colorHex: "#73BFA6")

        _ = await lifecycle.applyElapsed(now: farFuture, steps: 0, goal: 10_000)
        let second = await lifecycle.applyElapsed(now: farFuture, steps: 0, goal: 10_000)

        XCTAssertEqual(second, .noPet, "no pet left to tax")
        XCTAssertEqual(try graveCount(container), 1, "still one grave")
        XCTAssertEqual(spy.died, 1, "death notified only once")
    }

    // MARK: - Single-writer guarantee

    func testConcurrentSweepsProduceOneGrave() async throws {
        let (lifecycle, container, spy) = try makeLifecycle()
        await lifecycle.use(spy)
        await lifecycle.hatch(name: "Koa", colorHex: "#73BFA6")

        let future = farFuture
        async let a = lifecycle.applyElapsed(now: future, steps: 0, goal: 10_000)
        async let b = lifecycle.applyElapsed(now: future, steps: 0, goal: 10_000)
        let results = await [a, b]

        XCTAssertEqual(try graveCount(container), 1, "no duplicate grave under concurrency")
        XCTAssertEqual(spy.died, 1)
        XCTAssertTrue(results.contains(.died))
        XCTAssertTrue(results.contains(.noPet), "the loser sees no pet, not a second death")
    }

    // MARK: - Survival + feed

    func testSurvivalWritesSnapshotAndReportsHealth() async throws {
        let (lifecycle, _, spy) = try makeLifecycle()
        await lifecycle.use(spy)
        await lifecycle.hatch(name: "Koa", colorHex: "#73BFA6")

        // now == hatch time → zero elapsed checkpoints → survives at starting health.
        let outcome = await lifecycle.applyElapsed(now: Date(), steps: 8_000, goal: 10_000)

        guard case .survived = outcome else {
            return XCTFail("expected survival, got \(outcome)")
        }
        XCTAssertGreaterThanOrEqual(spy.snapshotUpdates, 1)
    }

    func testFeedSpendsALeafAndRaisesHealth() async throws {
        let (lifecycle, container, _) = try makeLifecycle()
        await lifecycle.hatch(name: "Koa", colorHex: "#73BFA6")

        await lifecycle.feed(steps: 10_000, goal: 10_000, now: Date())

        let ctx = ModelContext(container)
        let pet = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Pet>()).first)
        XCTAssertEqual(pet.leavesSpentToday, 1)
        XCTAssertEqual(pet.health, 0.85, accuracy: 0.0001, "0.75 + one half-heart step")
    }

    func testFeedWithNoLeavesIsANoOp() async throws {
        let (lifecycle, container, _) = try makeLifecycle()
        await lifecycle.hatch(name: "Koa", colorHex: "#73BFA6")

        await lifecycle.feed(steps: 0, goal: 10_000, now: Date())

        let ctx = ModelContext(container)
        let pet = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Pet>()).first)
        XCTAssertEqual(pet.leavesSpentToday, 0)
        XCTAssertEqual(pet.health, 0.75, accuracy: 0.0001)
    }

    // MARK: - Auto-feeding

    // A fixed summer day (no DST shift) at a given time.
    private func day(_ hour: Int, _ minute: Int = 0, dayOffset: Int = 0) -> Date {
        let cal = Calendar.current
        let base = cal.date(from: DateComponents(year: 2026, month: 6, day: 10 + dayOffset))!
        return cal.date(bySettingHour: hour, minute: minute, second: 0, of: base)!
    }

    /// Seed a pet directly so tests control health and the sweep window, then
    /// hand back a fresh lifecycle (its own context reads the seeded row).
    private func seededLifecycle(health: Double, lastSweep: Date) throws -> (PetLifecycle, ModelContainer, SpyEffects) {
        let (_, container, spy) = try makeLifecycle()
        let ctx = ModelContext(container)
        let pet = Pet(name: "Koa", colorHex: "#73BFA6")
        pet.health = health
        pet.lastTaxAppliedAt = lastSweep
        pet.leavesLedgerDate = Calendar.current.startOfDay(for: lastSweep)
        ctx.insert(pet)
        try ctx.save()
        return (PetLifecycle(modelContainer: container), container, spy)
    }

    private func pet(_ container: ModelContainer) throws -> Pet {
        try XCTUnwrap(try ModelContext(container).fetch(FetchDescriptor<Pet>()).first)
    }

    func testAutoFeedsAtCheckpointsWithoutWastingLeaves() async throws {
        let (lifecycle, container, spy) = try seededLifecycle(health: 1.0, lastSweep: day(7))
        await lifecycle.use(spy)
        // 3 leaves walked first thing in the morning.
        let history = StepLog(buckets: [.init(start: day(7, 5), steps: 3_000)])

        // Checkpoints every 90 min from 8:30 to 22:00. A leaf is eaten only
        // once it fits whole (at 0.90), so the 3 leaves go at 10:00, 13:00, 16:00
        // and the last 4 checkpoints drain 1.0 → 0.80.
        let outcome = await lifecycle.applyElapsed(now: day(23), steps: 3_000, goal: 10_000, history: history)

        XCTAssertEqual(outcome, .survived(.happy))
        let pet = try pet(container)
        XCTAssertEqual(pet.health, 0.80, accuracy: 0.0001)
        XCTAssertEqual(pet.leavesSpentToday, 3)
        XCTAssertEqual(spy.autoEaten, 3)
        XCTAssertEqual(spy.autoFeedEvents, 1, "one cheer per sweep, not per leaf")
    }

    func testLeavesEarnedLaterCantSaveAnEarlierCheckpoint() async throws {
        let (lifecycle, container, spy) = try seededLifecycle(health: 0.05, lastSweep: day(7))
        await lifecycle.use(spy)
        let history = StepLog(buckets: [.init(start: day(21), steps: 10_000)])

        let outcome = await lifecycle.applyElapsed(now: day(23), steps: 10_000, goal: 10_000, history: history)

        XCTAssertEqual(outcome, .died, "starved at 8:30, before those steps were walked")
        XCTAssertEqual(try graveCount(container), 1)
        XCTAssertEqual(spy.autoEaten, 0)
    }

    func testEarnedLeavesPreventDeath() async throws {
        let (lifecycle, container, spy) = try seededLifecycle(health: 0.05, lastSweep: day(7))
        await lifecycle.use(spy)
        let history = StepLog(buckets: [.init(start: day(7, 5), steps: 2_000)])

        // 8:30 hits zero → eats → 0.10; 10:00 → 0.05; 11:30 hits zero → eats → 0.10.
        let outcome = await lifecycle.applyElapsed(now: day(12), steps: 2_000, goal: 10_000, history: history)

        guard case .survived = outcome else { return XCTFail("expected survival, got \(outcome)") }
        XCTAssertEqual(try pet(container).health, 0.10, accuracy: 0.0001)
        XCTAssertEqual(spy.autoEaten, 2)
    }

    func testLeftoverLeavesAreEatenAtDayEnd() async throws {
        let (lifecycle, container, spy) = try seededLifecycle(health: 1.0, lastSweep: day(21))
        await lifecycle.use(spy)
        let history = StepLog(buckets: [.init(start: day(7, 5), steps: 1_000)])

        // 22:00 → 0.95: a whole leaf doesn't fit, so it waits. At day's end it
        // would reset anyway, so it tops the pet off. Next morning, before wake.
        _ = await lifecycle.applyElapsed(now: day(6, dayOffset: 1), steps: 0, goal: 10_000, history: history)

        XCTAssertEqual(try pet(container).health, 1.0, accuracy: 0.0001)
        XCTAssertEqual(spy.autoEaten, 1)
    }

    func testNoCheerWhenNothingWasEaten() async throws {
        let (lifecycle, _, spy) = try seededLifecycle(health: 1.0, lastSweep: day(7))
        await lifecycle.use(spy)

        _ = await lifecycle.applyElapsed(now: day(9), steps: 0, goal: 10_000)

        XCTAssertEqual(spy.autoFeedEvents, 0)
    }
}
