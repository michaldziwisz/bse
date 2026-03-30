import Foundation
import UserNotifications

final class SafetyNotificationController: NSObject, @preconcurrency UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    private let connectionLostIdentifier = "safety.connection-lost"

    override init() {
        super.init()
        center.delegate = self
    }

    func requestAuthorizationIfNeeded() async {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .badge, .sound, .timeSensitive])
        } catch {
            return
        }
    }

    func scheduleConnectionLostAlert(details: String) async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }

        center.removePendingNotificationRequests(withIdentifiers: [connectionLostIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Utracono połączenie"
        content.body = details
        content.sound = .default
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }

        let request = UNNotificationRequest(
            identifier: connectionLostIdentifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        do {
            try await center.add(request)
        } catch {
            return
        }
    }

    func clearConnectionLostAlert() {
        center.removePendingNotificationRequests(withIdentifiers: [connectionLostIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [connectionLostIdentifier])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list, .sound])
        } else {
            completionHandler([.alert, .sound])
        }
    }
}
