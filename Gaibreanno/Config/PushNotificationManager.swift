import UIKit
@preconcurrency import UserNotifications
import FirebaseCore
import FirebaseMessaging

/// Owns notification delegates for the lifetime of the application.
final class PushNotificationManager: NSObject {
    static let shared = PushNotificationManager()
    static let tokenDidChange = Notification.Name("PushNotificationManager.tokenDidChange")
    static let notificationWasOpened = Notification.Name("PushNotificationManager.notificationWasOpened")

    private(set) var isConfigured = false
    private(set) var currentToken: String?
    private(set) var lastOpenedNotification: [AnyHashable: Any]?
    private var registrationInProgress = false

    func configure() {
        guard !isConfigured else { return }
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let options = FirebaseOptions(contentsOfFile: path) else {
            NSLog("[Push] Missing or invalid GoogleService-Info.plist; push initialization skipped.")
            return
        }
        guard options.bundleID == Bundle.main.bundleIdentifier else {
            NSLog("[Push] Firebase Bundle ID does not match this app. Replace GoogleService-Info.plist; push initialization skipped.")
            return
        }
        if FirebaseApp.app() == nil { FirebaseApp.configure(options: options) }
        isConfigured = true
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
    }

    /// Called after the startup dialog closes, avoiding overlapping permission prompts.
    func requestAuthorizationAndRegister() {
        guard isConfigured, !registrationInProgress else { return }
        registrationInProgress = true
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                    if let error { NSLog("[Push] Notification authorization failed: %@", error.localizedDescription) }
                    DispatchQueue.main.async { self.completeRegistration(allowed: granted) }
                }
            } else {
                let allowed = [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus)
                DispatchQueue.main.async { self.completeRegistration(allowed: allowed) }
            }
        }
    }

    private func completeRegistration(allowed: Bool) {
        registrationInProgress = false
        guard allowed else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }

    func didRegister(deviceToken: Data) {
        guard isConfigured else { return }
        // App delegate swizzling is disabled; explicitly associate APNs and FCM tokens.
        Messaging.messaging().apnsToken = deviceToken
        Messaging.messaging().isAutoInitEnabled = true
        Messaging.messaging().token { [weak self] token, error in
            DispatchQueue.main.async {
                if let error { NSLog("[Push] FCM token request failed: %@", error.localizedDescription) }
                if let token { self?.updateToken(token) }
            }
        }
    }

    func didFailToRegister(_ error: Error) {
        NSLog("[Push] APNs registration failed: %@", error.localizedDescription)
    }

    private func updateToken(_ token: String?) {
        guard currentToken != token else { return }
        currentToken = token
        NotificationCenter.default.post(name: Self.tokenDidChange, object: self,
                                        userInfo: token.map { ["token": $0] })
        #if DEBUG
        if let token { print("[Push] FCM registration token: \(token)") }
        #endif
        // Observe tokenDidChange to upload the token when a backend endpoint is provided.
    }
}

extension PushNotificationManager: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        DispatchQueue.main.async { self.updateToken(fcmToken) }
    }
}

extension PushNotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                           willPresent notification: UNNotification,
                                           withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound, .badge])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                           didReceive response: UNNotificationResponse,
                                           withCompletionHandler completionHandler: @escaping () -> Void) {
        DispatchQueue.main.async {
            let payload = response.notification.request.content.userInfo
            self.lastOpenedNotification = payload
            NotificationCenter.default.post(name: Self.notificationWasOpened, object: self,
                                            userInfo: ["payload": payload, "actionIdentifier": response.actionIdentifier])
            completionHandler()
        }
    }
}
