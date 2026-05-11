import Foundation
import SwiftData
import WidgetKit

@Observable
final class PetManager {
    private var modelContext: ModelContext
    let healthKit: HealthKitService

    var todaySteps: Int { healthKit.todaySteps }
    var isLoading = false

    init(modelContext: ModelContext, healthKit: HealthKitService) {
        self.modelContext = modelContext
        self.healthKit = healthKit
    }

    @MainActor
    func refresh(pet: Pet) async {
        isLoading = true
        defer { isLoading = false }

        await healthKit.requestAuthorization()
        _ = await healthKit.stepsToday()

        let today = Calendar.current.startOfDay(for: Date())
        let storedGoal = UserDefaults.standard.integer(forKey: "stepGoal")
        let goal = storedGoal > 0 ? storedGoal : 10_000

        if pet.lastCheckedDate < today {
            var cursor = pet.lastCheckedDate
            while cursor < today {
                let daySteps = await healthKit.steps(for: cursor)
                let tier = healthKit.stepTier(for: daySteps, goal: goal)
                pet.totalStepsLifetime += daySteps
                pet.health = min(1.0, max(0.0, pet.health + tier.healthDelta))
                cursor = Calendar.current.date(byAdding: .day, value: 1, to: cursor)!
            }
            pet.lastCheckedDate = today
        }

        if pet.health <= 0 {
            killPet(pet)
            PetSnapshot.clear()
            WidgetCenter.shared.reloadAllTimelines()
        } else {
            writeSnapshot(pet: pet, goal: goal)
        }
    }

    func feed(pet: Pet, goal: Int = 10_000) {
        rollLedgerIfNeeded(pet: pet)
        guard bambooAvailable(for: pet, goal: goal) > 0 else { return }
        guard pet.health < 1.0 else { return }
        pet.bambooSpentToday += 1
        pet.health = min(1.0, pet.health + 0.1)
        writeSnapshot(pet: pet, goal: goal)
    }

    func writeSnapshot(pet: Pet, goal: Int = 10_000) {
        let snapshot = PetSnapshot(
            name: pet.name,
            colorHex: pet.colorHex,
            health: pet.health,
            stepsToday: todaySteps,
            stepGoal: goal,
            bambooEarned: bambooEarned(goal: goal),
            bambooAvailable: bambooAvailable(for: pet, goal: goal),
            updatedAt: Date()
        )
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Bamboo earned by today's steps minus what's been fed.
    func bambooAvailable(for pet: Pet, goal: Int = 10_000) -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        let spent = pet.bambooLedgerDate < today ? 0 : pet.bambooSpentToday
        let earned = BambooLedger.earned(steps: todaySteps, goal: goal)
        return max(0, earned - spent)
    }

    func bambooEarned(goal: Int = 10_000) -> Int {
        BambooLedger.earned(steps: todaySteps, goal: goal)
    }

    private func rollLedgerIfNeeded(pet: Pet) {
        let today = Calendar.current.startOfDay(for: Date())
        if pet.bambooLedgerDate < today {
            pet.bambooSpentToday = 0
            pet.bambooLedgerDate = today
        }
    }

    private func killPet(_ pet: Pet) {
        let dead = GraveyardPet(from: pet)
        modelContext.insert(dead)
        modelContext.delete(pet)
    }
}
