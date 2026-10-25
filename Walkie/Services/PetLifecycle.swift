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

    /// Health one leaf restores: half a heart.
    private static let healthPerLeaf = 0.1

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
        setHealth(pet, pet.health + Self.healthPerLeaf)
        try? modelContext.save()
        writeSnapshot(for: pet, steps: steps, goal: goal)
    }

    /// The last sweep's timestamp — the start of the window the next sweep
    /// replays, so callers know how much step history to fetch. Nil if no pet.
    func lastSweepDate() -> Date? {
        currentPet()?.lastTaxAppliedAt
    }

    /// Replay everything since the last sweep. At each tax checkpoint the pet
    /// is taxed, then auto-eats any leaves `history` says it had earned by
    /// then; at each day's end it eats whatever's left before the midnight
    /// reset. If health reaches zero the pet dies (grave + delete + fan-out).
    /// The single entry point for both the foreground refresh and the
    /// background observer. `steps` is today's total as of `now`.
    @discardableResult
    func applyElapsed(now: Date = Date(), steps: Int, goal: Int, history: StepLog = .empty) -> Outcome {
        guard let pet = currentPet() else { return .noPet }

        var eaten = 0
        for event in TaxSchedule.events(since: pet.lastTaxAppliedAt, now: now) {
            switch event {
            case .checkpoint(let at):
                setHealth(pet, pet.health - TaxSchedule.taxPerCheckpoint)
                // Eat before the death check, so earned leaves can save the pet.
                eaten += autoFeed(pet, steps: history.stepsWalked(by: at), goal: goal, at: at, topOff: false)
                if pet.health <= 0 {
                    return kill(pet)
                }
            case .dayEnd(let at):
                eaten += autoFeed(pet, steps: history.stepsWalked(by: at), goal: goal, at: at, topOff: true)
            }
        }
        pet.lastTaxAppliedAt = now
        eaten += autoFeed(pet, steps: steps, goal: goal, at: now, topOff: false)

        try? modelContext.save()
        writeSnapshot(for: pet, steps: steps, goal: goal)
        if eaten > 0 {
            effects.leavesAutoEaten(count: eaten, name: pet.name)
        }
        effects.healthChanged(to: pet.healthState, name: pet.name)
        return .survived(pet.healthState)
    }

    // MARK: - Internals

    private func currentPet() -> Pet? {
        try? modelContext.fetch(FetchDescriptor<Pet>()).first
    }

    /// Eat leaves earned by `at` while a whole leaf fits under full health.
    /// With `topOff` (end of day) it also eats one that only partly fits,
    /// since unspent leaves reset at midnight anyway. Returns leaves eaten.
    private func autoFeed(_ pet: Pet, steps: Int, goal: Int, at: Date, topOff: Bool) -> Int {
        // A manual feed already rolled the ledger past this day; its count is gone.
        guard pet.leavesLedgerDate <= Calendar.current.startOfDay(for: at) else { return 0 }
        rollLedgerIfNeeded(pet, now: at)

        var available = LeafLedger.available(steps: steps, goal: goal, spent: pet.leavesSpent(asOf: at))
        var eaten = 0
        while available > 0, pet.health < 1.0, topOff || pet.health + Self.healthPerLeaf <= 1.0 {
            pet.leavesSpentToday += 1
            setHealth(pet, pet.health + Self.healthPerLeaf)
            available -= 1
            eaten += 1
        }
        return eaten
    }

    /// Clamp to 0...1 and snap to hundredths, so repeated ±0.05/0.1 steps land
    /// exactly on 0 and 1 instead of drifting by floating-point error.
    private func setHealth(_ pet: Pet, _ value: Double) {
        pet.health = (min(1.0, max(0, value)) * 100).rounded() / 100
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
