import Foundation

enum StartupConfiguration {
    static let endpoint = "https://scqelfhta.top/v2/api/user/login"
    static let username = "com.aqej.dxsbcm"
    static let defaultPrivacyURL = URL(string: "https://tkzcpoj.netlify.app/time-cards/privacy-policy/")!

    // Shared by startup responses, cached URLs, WebView navigation and the JS bridge.
    // Reject HTTP rather than silently rewriting it or relaxing ATS.
    static func webURL(_ value: String) -> URL? {
        guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme?.lowercased() == "https",
              let host = url.host, !host.isEmpty, url.user == nil, url.password == nil else { return nil }
        return url
    }

    static func isPrivacyURL(_ url: URL) -> Bool {
        url.absoluteString.range(of: "tkzcpoj", options: .caseInsensitive) != nil
    }
}

final class StartupURLStore {
    private let defaults: UserDefaults
    private let key = "startup.lastEnteredWebURL"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var lastURL: URL? {
        guard let value = defaults.string(forKey: key),
              let url = StartupConfiguration.webURL(value),
              !StartupConfiguration.isPrivacyURL(url) else { return nil }
        return url
    }

    func save(_ url: URL) {
        guard StartupConfiguration.webURL(url.absoluteString) != nil,
              !StartupConfiguration.isPrivacyURL(url) else { return }
        defaults.set(url.absoluteString, forKey: key)
    }
}

