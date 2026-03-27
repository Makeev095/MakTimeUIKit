import UIKit
import UserNotifications

/// Обычные APNs-уведомления о сообщениях (отличные от VoIP PushKit). Payload должен содержать `conversationId` рядом с `aps` или в `data.conversationId`.
enum ChatPushNotifications {
    static func configure() {
        UNUserNotificationCenter.current().delegate = ChatPushCenterDelegate.shared
    }

    static func registerForChatAlertsIfNeeded() {
        Task {
            do {
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .badge, .sound])
                guard granted else { return }
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } catch {
                print("[Push] notification permission: \(error)")
            }
        }
    }

    static func conversationId(from userInfo: [AnyHashable: Any]) -> String? {
        if let id = userInfo["conversationId"] as? String { return id }
        if let data = userInfo["data"] as? [String: Any], let id = data["conversationId"] as? String { return id }
        return nil
    }
}

private final class ChatPushCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ChatPushCenterDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let convId = ChatPushNotifications.conversationId(from: userInfo) {
            NotificationCenter.default.post(
                name: .makTimeOpenChatFromNotification,
                object: nil,
                userInfo: ["conversationId": convId]
            )
        }
        completionHandler()
    }
}
