import Foundation

/// Thin view-model for the home screen. Owns no SwiftData writes — every
/// mutation routes through the shared `PetLifecycle` actor. It exists only to
/// drive the refresh spinner and expose derived, read-only values to the view.
@MainActor
@Observable
final class PetManager {
    private let lifecycle: PetLifecycle
    let healthKit: HealthKitService

    var todaySteps: Int { healthKit.todaySteps }
    var isLoading = false

    init(lifecycle: PetLifecycle, healthKit: HealthKitService) {
        self.lifecycle = lifecycle
        self.healthKit = healthKit
    }

    /// Pull fresh steps and run the tax sweep through the actor.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        await healthKit.requestAuthorization()
        let steps = await healthKit.stepsToday()
        _ = await lifecycle.applyElapsed(steps: steps, goal: HealthKitService.stepGoal)
    }

    /// Spend a leaf. Fire-and-forget; the @Query-backed view refreshes when the
    /// actor's save merges into the main context.
    func feed(goal: Int) {
        let steps = healthKit.todaySteps
        Task { await lifecycle.feed(steps: steps, goal: goal) }
    }

    /// Leaves the user can spend right now — derived, no persistence.
    func leavesAvailable(for pet: Pet, goal: Int) -> Int {
        LeafLedger.available(steps: todaySteps, goal: goal, spent: pet.leavesSpent())
    }
}
