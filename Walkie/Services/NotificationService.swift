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

    // Scheduled daily reminder if user hasn't hit 3k steps by 6pm
    func scheduleDailyReminder(petName: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["pet.daily"])

        let content = UNMutableNotificationContent()
        content.title = "\(petName) needs a walk!"
        content.body = "You haven't hit your step goal today. \(petName) is getting hungry."
        content.sound = .default

        var components = DateComponents()
        components.hour = 18
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "pet.daily", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
