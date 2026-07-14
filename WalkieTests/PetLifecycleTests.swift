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
}
