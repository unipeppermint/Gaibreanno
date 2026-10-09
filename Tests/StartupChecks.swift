import Foundation

@main
struct StartupChecks {
    static func main() {
        let policy = StartupConfiguration.defaultPrivacyURL
        precondition(StartupConfiguration.isPrivacyURL(policy))
        precondition(StartupConfiguration.isPrivacyURL(URL(string: "https://example.com/TKZCPOJ")!))
        for value in ["", "garbage", "http://example.com", " HTTP://example.com/path ", "http://tkzcpoj.example/privacy", "file:///tmp/a", "javascript:alert(1)", "https://", "https://user:pass@example.com"] {
            precondition(StartupConfiguration.webURL(value) == nil, "Accepted invalid URL: \(value)")
        }
        let website = StartupConfiguration.webURL(" https://example.com/start?q=1 ")!
        precondition(!StartupConfiguration.isPrivacyURL(website))
        precondition(StartupConfiguration.webURL("HTTPS://example.com/path") != nil)
        let cached = URL(string: "https://example.com/cached")!
        precondition(StartupConfiguration.destinationURL(receivedURL: website, cachedURL: cached) == website)
        precondition(StartupConfiguration.destinationURL(receivedURL: website, cachedURL: nil) == website)
        precondition(StartupConfiguration.destinationURL(receivedURL: nil, cachedURL: cached) == cached)
        precondition(StartupConfiguration.destinationURL(receivedURL: policy, cachedURL: cached) == cached)
        precondition(StartupConfiguration.destinationURL(receivedURL: policy, cachedURL: nil) == nil)
        precondition(StartupConfiguration.destinationURL(receivedURL: nil, cachedURL: nil) == nil)
        precondition(StartupConfiguration.destinationURL(receivedURL: nil, cachedURL: policy) == nil)
        precondition(StartupConfiguration.destinationURL(receivedURL: policy, cachedURL: URL(string: "http://example.com")) == nil)
        precondition(StartupConfiguration.destinationURL(receivedURL: URL(string: "http://example.com"), cachedURL: cached) == cached)
        print("Startup destination and cached fallback checks passed")
        let suite = "StartupChecks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = StartupURLStore(defaults: defaults)
        precondition(store.lastURL == nil)
        defaults.set("https://example.com/redirected", forKey: "startup.lastEnteredWebURL")
        precondition(store.lastURL == nil, "Legacy WebView URLs have no reliable API provenance")
        defaults.set("http://example.com/old", forKey: "startup.lastAPIWebURL")
        precondition(store.lastURL == nil, "Legacy HTTP cache must not be used")
        store.saveAPIURL(website)
        precondition(StartupURLStore(defaults: defaults).lastURL == website)
        store.saveAPIURL(policy)
        precondition(store.lastURL == website, "Policy must not replace fallback URL")
        store.saveAPIURL(URL(string: "file:///tmp/a")!)
        precondition(store.lastURL == website)
        store.saveAPIURL(URL(string: "http://example.com/new")!)
        precondition(store.lastURL == website, "HTTP must not replace a valid HTTPS cache")
        let nextAPIURL = URL(string: "https://example.com/next-entry")!
        store.saveAPIURL(nextAPIURL)
        precondition(StartupURLStore(defaults: defaults).lastURL == nextAPIURL)
        precondition(StartupConfiguration.destinationURL(receivedURL: policy, cachedURL: store.lastURL) == nextAPIURL)
        precondition(StartupConfiguration.destinationURL(receivedURL: nil, cachedURL: store.lastURL) == nextAPIURL)
        precondition(StartupScriptBridge.externalURL(from: ["url": "http://example.com", "href": "https://example.com"])?.scheme == "https")
        for body: Any in [" https://example.com/path ", "//example.com/path", "example.com/path",
                          ["url": "https://example.com/path"], ["href": "https://example.com/path"],
                          ["link": "https://example.com/path"], ["target": "https://example.com/path"],
                          ["url": "javascript:alert(1)", "href": "https://example.com/path"]] {
            precondition(StartupScriptBridge.externalURL(from: body)?.absoluteString == "https://example.com/path")
        }
        for body: Any in ["http://example.com", "HTTP://example.com", ["url": "http://example.com"], ["href": "http://example.com"], ["link": "http://example.com"], ["target": "http://example.com"], 42, NSNull(), ["url": 42], ["other": "https://example.com"], "",
                          "javascript:alert(1)", "file:///tmp/a.html", "data:text/html,a.b", "/relative.html",
                          "https://user:pass@example.com"] {
            precondition(StartupScriptBridge.externalURL(from: body) == nil)
        }
        print("JavaScript bridge payload and URL validation checks passed")
        print("Startup URL validation, classification and persistence checks passed")
    }
}
