import Foundation
import SwiftData

@Observable
final class PetManager {
    private var modelContext: ModelContext
    let healthKit: HealthKitService

    var todaySteps: Int = 0
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
        todaySteps = await healthKit.stepsToday()

        let today = Calendar.current.startOfDay(for: Date())
        guard pet.lastCheckedDate < today else { return }

        let storedGoal = UserDefaults.standard.integer(forKey: "stepGoal")
        let goal = storedGoal > 0 ? storedGoal : 10_000

        var cursor = pet.lastCheckedDate
        while cursor < today {
            let daySteps = await healthKit.steps(for: cursor)
            let tier = healthKit.stepTier(for: daySteps, goal: goal)
            pet.totalStepsLifetime += daySteps
            pet.health = min(1.0, max(0.0, pet.health + tier.healthDelta))
            cursor = Calendar.current.date(byAdding: .day, value: 1, to: cursor)!
        }

        pet.lastCheckedDate = today
        if pet.health <= 0 {
            killPet(pet)
        }
    }

    func feed(pet: Pet, goal: Int = 10_000) {
        guard healthKit.stepTier(for: todaySteps, goal: goal).canFeed else { return }
        pet.health = min(1.0, pet.health + 0.1)
    }

    private func killPet(_ pet: Pet) {
        let dead = GraveyardPet(from: pet)
        modelContext.insert(dead)
        modelContext.delete(pet)
    }
}
