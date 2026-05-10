import SwiftUI
import SwiftData

@main
struct WalkieApp: App {
    private let container: ModelContainer = {
        let schema = Schema([Pet.self, GraveyardPet.self])
        return try! ModelContainer(for: schema)
    }()

    @State private var healthKit = HealthKitService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .environment(healthKit)
                .task { await setup() }
        }
    }

    private func setup() async {
        await NotificationService.shared.requestPermission()
        await healthKit.requestAuthorization()
        await healthKit.enableBackgroundDelivery()
        healthKit.startObserving(container: container)

        // Schedule a fallback 6pm daily reminder
        scheduleReminderIfNeeded()
    }

    private func scheduleReminderIfNeeded() {
        let context = container.mainContext
        let descriptor = FetchDescriptor<Pet>()
        if let pet = try? context.fetch(descriptor).first {
            NotificationService.shared.scheduleDailyReminder(petName: pet.name)
        }
    }
}
