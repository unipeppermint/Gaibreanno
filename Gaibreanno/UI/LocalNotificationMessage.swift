import Foundation

/// Bundled inbox content, available offline in both Debug and Release builds.
struct LocalNotificationMessage {
    let id: String
    let title: String
    let body: String

    static let welcome = LocalNotificationMessage(
        id: "welcome-v1",
        title: "Welcome to Time Cards!",
        body: "Your adventure starts here. Build your deck, explore the card library, and take on your first challenge. Good luck!"
    )

    private var readKey: String { "localInbox.read.\(id)" }
    var isRead: Bool { UserDefaults.standard.bool(forKey: readKey) }
    func markAsRead() { UserDefaults.standard.set(true, forKey: readKey) }
}
