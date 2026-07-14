import SwiftUI
import SwiftData

@main
struct WalkieApp: App {
    private let container: ModelContainer
    // The single lifecycle owner, shared between the foreground and the
    // HealthKit observer so a death is written exactly once.
    private let lifecycle: PetLifecycle

    @State private var healthKit = HealthKitService()

    init() {
        let schema = Schema([Pet.self, GraveyardPet.self])
        let config = ModelConfiguration(schema: schema)
        self.container = WalkieApp.loadContainer(schema: schema, config: config)
        self.lifecycle = PetLifecycle(modelContainer: container)
    }

    /// Load the store, or — if it can't be opened/migrated — recreate it from
    /// scratch rather than crash-looping on launch. Self-healing beats a brick.
    private static func loadContainer(schema: Schema, config: ModelConfiguration) -> ModelContainer {
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            let url = config.url
            let dir = url.deletingLastPathComponent()
            let name = url.lastPathComponent
            for file in [name, name + "-wal", name + "-shm"] {
                try? FileManager.default.removeItem(at: dir.appendingPathComponent(file))
            }
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return try! ModelContainer(for: schema, configurations: config)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .environment(healthKit)
                .environment(\.petLifecycle, lifecycle)
                .task { await setup() }
        }
    }

    private func setup() async {
        await NotificationService.shared.requestPermission()
        await healthKit.requestAuthorization()
        await healthKit.enableBackgroundDelivery()
        healthKit.startObserving(lifecycle: lifecycle)

        // Schedule a fallback 6pm daily reminder
        scheduleReminderIfNeeded()
    }

    private func scheduleReminderIfNeeded() {
        let context = container.mainContext
        let descriptor = FetchDescriptor<Pet>()
        if let pet = try? context.fetch(descriptor).first {
            NotificationService.shared.scheduleWalkReminders(petName: pet.name)
            AppIconManager.sync(toColorHex: pet.colorHex)
        }
    }
}
