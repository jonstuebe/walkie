import SwiftData
import Foundation
import WidgetKit

// Runs on a background ModelContext so HealthKit observer callbacks
// can safely write to SwiftData without touching the main actor's context.
@ModelActor
actor BackgroundPetUpdater {
    func update(todaySteps: Int, healthKit: HealthKitService) {
        let descriptor = FetchDescriptor<Pet>()
        guard let pet = try? modelContext.fetch(descriptor).first else { return }

        let today = Calendar.current.startOfDay(for: Date())

        // Process any days we missed since last check
        var cursor = pet.lastCheckedDate
        var stepDaysToProcess: [(date: Date, steps: Int)] = []

        while cursor < today {
            stepDaysToProcess.append((cursor, 0))
            cursor = Calendar.current.date(byAdding: .day, value: 1, to: cursor)!
        }

        // We already have todaySteps from the caller; historical days are
        // fetched synchronously here. For background simplicity we apply a
        // health delta based on the step tier, using todaySteps for today.
        let storedGoal = UserDefaults.standard.integer(forKey: "stepGoal")
        let goal = storedGoal > 0 ? storedGoal : 10_000

        for (index, day) in stepDaysToProcess.enumerated() {
            let steps = index == stepDaysToProcess.indices.last ? todaySteps : 0
            let tier = healthKit.stepTier(for: steps, goal: goal)
            pet.totalStepsLifetime += steps
            pet.health = min(1.0, max(0.0, pet.health + tier.healthDelta))
        }

        pet.lastCheckedDate = today

        if pet.health <= 0 {
            let petName = pet.name
            let dead = GraveyardPet(from: pet)
            modelContext.insert(dead)
            modelContext.delete(pet)
            try? modelContext.save()
            PetSnapshot.clear()
            WidgetCenter.shared.reloadAllTimelines()
            NotificationService.shared.sendDeathNotification(petName: petName)
            return
        }

        try? modelContext.save()

        let earned = BambooLedger.earned(steps: todaySteps, goal: goal)
        let spent = pet.bambooLedgerDate < today ? 0 : pet.bambooSpentToday
        let available = max(0, earned - spent)
        let snapshot = PetSnapshot(
            name: pet.name,
            colorHex: pet.colorHex,
            health: pet.health,
            stepsToday: todaySteps,
            stepGoal: goal,
            bambooEarned: earned,
            bambooAvailable: available,
            updatedAt: Date()
        )
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()

        // Fire appropriate notification based on health level
        switch pet.healthState {
        case .critical:
            NotificationService.shared.sendCriticalNotification(petName: pet.name)
        case .hungry:
            NotificationService.shared.sendHungryNotification(petName: pet.name)
        default:
            break
        }
    }
}
