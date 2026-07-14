import UserNotifications

final class NotificationService: Sendable {
    static let shared = NotificationService()

    func requestPermission() async {
        try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    func sendHungryNotification(petName: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(petName) is starving!"
        content.body = "Get some steps in before it's too late."
        content.sound = .default

        // Using a fixed identifier so repeated firings replace rather than stack
        let request = UNNotificationRequest(identifier: "pet.hungry", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func sendCriticalNotification(petName: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(petName) is critical!"
        content.body = "\(petName) won't survive another day without steps. Walk now!"
        content.sound = .defaultCritical

        let request = UNNotificationRequest(identifier: "pet.critical", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func sendDeathNotification(petName: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(petName) has passed away..."
        content.body = "Your koala starved. Visit the graveyard to pay your respects."
        content.sound = .default

        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        let request = UNNotificationRequest(identifier: "pet.death", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // Friendly walking nudges spaced through the day. Each fires daily on a
    // repeating calendar trigger; identifiers are stable so re-scheduling
    // (e.g. on app launch or pet rename) replaces the existing requests.
    func scheduleWalkReminders(petName: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: Self.walkReminderIdentifiers)
        // Legacy identifier from the earlier single-reminder implementation.
        center.removePendingNotificationRequests(withIdentifiers: ["pet.daily"])

        for slot in Self.walkReminderSlots {
            let content = UNMutableNotificationContent()
            content.title = slot.title(petName: petName)
            content.body = slot.body(petName: petName)
            content.sound = .default
            content.threadIdentifier = "walk.reminder"

            var components = DateComponents()
            components.hour = slot.hour
            components.minute = slot.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: slot.identifier, content: content, trigger: trigger)
            center.add(request)
        }
    }

    private static let walkReminderSlots: [WalkReminderSlot] = [
        .init(
            identifier: "walk.reminder.morning",
            hour: 9, minute: 0,
            titleTemplate: "Good morning from %@",
            bodyTemplate: "Kick off the day with a walk — %@ is ready to roll."
        ),
        .init(
            identifier: "walk.reminder.midday",
            hour: 12, minute: 30,
            titleTemplate: "Stretch break with %@?",
            bodyTemplate: "A lunchtime loop will earn %@ a fresh leaf."
        ),
        .init(
            identifier: "walk.reminder.afternoon",
            hour: 15, minute: 30,
            titleTemplate: "%@ is restless",
            bodyTemplate: "Beat the afternoon slump with a quick walk together."
        ),
        .init(
            identifier: "walk.reminder.evening",
            hour: 18, minute: 0,
            titleTemplate: "Evening stroll with %@?",
            bodyTemplate: "Top off today's steps before %@ heads to bed."
        ),
    ]

    private static var walkReminderIdentifiers: [String] {
        walkReminderSlots.map(\.identifier)
    }
}

private struct WalkReminderSlot {
    let identifier: String
    let hour: Int
    let minute: Int
    let titleTemplate: String
    let bodyTemplate: String

    func title(petName: String) -> String {
        String(format: titleTemplate, petName)
    }

    func body(petName: String) -> String {
        String(format: bodyTemplate, petName)
    }
}
