import Foundation

@main
struct StartupChecks {
    static func main() {
        let policy = StartupConfiguration.defaultPrivacyURL
        precondition(StartupConfiguration.isPrivacyURL(policy))
        precondition(StartupConfiguration.isPrivacyURL(URL(string: "https://example.com/TKZCPOJ")!))
        for value in ["", "garbage", "file:///tmp/a", "javascript:alert(1)", "https://", "https://user:pass@example.com"] {
            precondition(StartupConfiguration.webURL(value) == nil, "Accepted invalid URL: \(value)")
        }
        let website = StartupConfiguration.webURL(" https://example.com/start?q=1 ")!
        precondition(!StartupConfiguration.isPrivacyURL(website))
        let suite = "StartupChecks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = StartupURLStore(defaults: defaults)
        precondition(store.lastURL == nil)
        store.save(website)
        precondition(StartupURLStore(defaults: defaults).lastURL == website)
        store.save(policy)
        precondition(store.lastURL == website, "Policy must not replace fallback URL")
        store.save(URL(string: "file:///tmp/a")!)
        precondition(store.lastURL == website)
        print("Startup URL validation, classification and persistence checks passed")
    }
}
