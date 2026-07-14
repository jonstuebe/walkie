import Foundation
import WidgetKit

/// The non-SwiftData side effects a lifecycle transition fans out to.
/// Kept behind a protocol so tests can substitute a spy and assert that a
/// death fires exactly one notification, the snapshot is written once, etc.
protocol LifecycleEffects: Sendable {
    /// A pet was created. Sync the app icon to its color and schedule reminders.
    func petHatched(name: String, colorHex: String)
    /// The current pet's snapshot changed. Persist it for the widget and refresh.
    func snapshotUpdated(_ snapshot: PetSnapshot)
    /// The pet died. Clear the widget snapshot and refresh.
    func snapshotCleared()
    /// The pet died. Notify the user.
    func petDied(name: String)
    /// The pet survived a tax sweep at the given health. Nudge if it's getting low.
    func healthChanged(to state: Pet.HealthState, name: String)
}

/// Production adapter: the real app-icon, notification, snapshot, and widget calls.
struct SystemLifecycleEffects: LifecycleEffects {
    func petHatched(name: String, colorHex: String) {
        NotificationService.shared.scheduleWalkReminders(petName: name)
        Task { @MainActor in AppIconManager.sync(toColorHex: colorHex) }
    }

    func snapshotUpdated(_ snapshot: PetSnapshot) {
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func snapshotCleared() {
        PetSnapshot.clear()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func petDied(name: String) {
        NotificationService.shared.sendDeathNotification(petName: name)
    }

    func healthChanged(to state: Pet.HealthState, name: String) {
        switch state {
        case .critical: NotificationService.shared.sendCriticalNotification(petName: name)
        case .hungry:   NotificationService.shared.sendHungryNotification(petName: name)
        default:        break
        }
    }
}
