import Foundation
import SwiftData
import SwiftUI

/// The single owner of every write to a pet's life. Instantiated once and shared
/// between the foreground and the HealthKit observer, so both mutate through one
/// serialized actor and one `ModelContext` — a death is recorded exactly once.
///
/// Aliveness = a `Pet` row exists. Death deletes the `Pet` and inserts a
/// `GraveyardPet`; a `#Unique` constraint on the grave's `petID` is a backstop.
@ModelActor
actor PetLifecycle {
    enum Outcome: Sendable, Equatable {
        case noPet
        case survived(Pet.HealthState)
        case died
    }

    // Overridable for tests; production uses the real singletons.
    private var effects: LifecycleEffects = SystemLifecycleEffects()

    /// Substitute the side-effect adapter (tests inject a spy).
    func use(_ effects: LifecycleEffects) {
        self.effects = effects
    }

    // MARK: - Verbs

    /// Create the pet. Replaces the inline insert that lived in onboarding.
    func hatch(name: String, colorHex: String) {
        let pet = Pet(name: name, colorHex: colorHex)
        modelContext.insert(pet)
        try? modelContext.save()
        effects.petHatched(name: name, colorHex: colorHex)
    }

    /// Spend one leaf to restore a half-heart, if leaves are available and the
    /// pet isn't already full.
    func feed(steps: Int, goal: Int, now: Date = Date()) {
        guard let pet = currentPet() else { return }
        rollLedgerIfNeeded(pet, now: now)
        let available = LeafLedger.available(steps: steps, goal: goal, spent: pet.leavesSpent(asOf: now))
        guard available > 0, pet.health < 1.0 else { return }
        pet.leavesSpentToday += 1
        pet.health = min(1.0, pet.health + 0.1)
        try? modelContext.save()
        writeSnapshot(for: pet, steps: steps, goal: goal)
    }

    /// Apply any tax checkpoints elapsed since the last sweep. If health reaches
    /// zero the pet dies (grave + delete + fan-out). The single entry point for
    /// both the foreground refresh and the background observer.
    @discardableResult
    func applyElapsed(now: Date = Date(), steps: Int, goal: Int) -> Outcome {
        guard let pet = currentPet() else { return .noPet }

        let elapsed = TaxSchedule.checkpointsElapsed(since: pet.lastTaxAppliedAt, now: now)
        if elapsed > 0 {
            pet.health = max(0, pet.health - TaxSchedule.taxPerCheckpoint * Double(elapsed))
        }
        pet.lastTaxAppliedAt = now

        if pet.health <= 0 {
            return kill(pet)
        }

        try? modelContext.save()
        writeSnapshot(for: pet, steps: steps, goal: goal)
        effects.healthChanged(to: pet.healthState, name: pet.name)
        return .survived(pet.healthState)
    }

    // MARK: - Internals

    private func currentPet() -> Pet? {
        try? modelContext.fetch(FetchDescriptor<Pet>()).first
    }

    private func rollLedgerIfNeeded(_ pet: Pet, now: Date) {
        let today = Calendar.current.startOfDay(for: now)
        if pet.leavesLedgerDate < today {
            pet.leavesSpentToday = 0
            pet.leavesLedgerDate = today
        }
    }

    /// The death transition. Gated by `currentPet()` above, so a second call on
    /// an already-dead pet never reaches here — the single serialized actor is
    /// what guarantees a death is recorded exactly once.
    private func kill(_ pet: Pet) -> Outcome {
        let name = pet.name
        modelContext.insert(GraveyardPet(from: pet))
        modelContext.delete(pet)
        try? modelContext.save()
        effects.snapshotCleared()
        effects.petDied(name: name)
        return .died
    }

    @discardableResult
    private func writeSnapshot(for pet: Pet, steps: Int, goal: Int) -> PetSnapshot {
        let snapshot = PetSnapshot(
            name: pet.name,
            colorHex: pet.colorHex,
            health: pet.health,
            stepsToday: steps,
            stepGoal: goal,
            leavesEarned: LeafLedger.earned(steps: steps, goal: goal),
            leavesAvailable: LeafLedger.available(steps: steps, goal: goal, spent: pet.leavesSpent(asOf: Date())),
            updatedAt: Date()
        )
        effects.snapshotUpdated(snapshot)
        return snapshot
    }
}

// MARK: - Environment

private struct PetLifecycleKey: EnvironmentKey {
    static let defaultValue: PetLifecycle? = nil
}

extension EnvironmentValues {
    /// The app's single shared lifecycle owner. Non-nil in the running app;
    /// nil only in previews that don't inject one.
    var petLifecycle: PetLifecycle? {
        get { self[PetLifecycleKey.self] }
        set { self[PetLifecycleKey.self] = newValue }
    }
}
