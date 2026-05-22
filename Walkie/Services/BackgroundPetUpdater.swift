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

        let storedGoal = UserDefaults.standard.integer(forKey: "stepGoal")
        let goal = storedGoal > 0 ? storedGoal : 10_000

        let died = pet.applyMissedTaxes()

        if died {
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

        let today = Calendar.current.startOfDay(for: Date())
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
