import Foundation

@main
struct GaibreannoStartupChecks {
    static func main() {
        let suite = "GaibreannoStartupChecks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        // A fresh install requires no cached destination or migration marker.
        GaibreannoLegacyStartupCleanup.removeCachedDestinations(defaults: defaults)
        precondition(defaults.persistentDomain(forName: suite)?.isEmpty != false)

        let savedGame = Data("existing-player-progress".utf8)
        defaults.set(savedGame, forKey: "time-cards.saved-game.v1")
        defaults.set(true, forKey: "localInbox.read.welcome-v1")
        defaults.set("https://example.com/old-entry", forKey: "startup.lastAPIWebURL")
        defaults.set("https://example.com/old-redirect", forKey: "startup.lastEnteredWebURL")

        // Upgrade and repeated launch cleanup must preserve unrelated player data.
        for _ in 0..<2 {
            GaibreannoLegacyStartupCleanup.removeCachedDestinations(defaults: defaults)
            precondition(defaults.object(forKey: "startup.lastAPIWebURL") == nil)
            precondition(defaults.object(forKey: "startup.lastEnteredWebURL") == nil)
            precondition(defaults.data(forKey: "time-cards.saved-game.v1") == savedGame)
            precondition(defaults.bool(forKey: "localInbox.read.welcome-v1"))
        }

        print("Native startup migration checks passed; existing player data preserved")
    }
}
