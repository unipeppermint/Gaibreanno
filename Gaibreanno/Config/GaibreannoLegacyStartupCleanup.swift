import Foundation

enum GaibreannoLegacyStartupCleanup {
    static func removeCachedDestinations(defaults: UserDefaults = .standard) {
        // Remove obsolete destinations without touching game saves or preferences.
        defaults.removeObject(forKey: "startup.lastAPIWebURL")
        defaults.removeObject(forKey: "startup.lastEnteredWebURL")
    }
}
