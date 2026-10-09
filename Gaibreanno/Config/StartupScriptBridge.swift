import Foundation

/// JavaScript: window.webkit.messageHandlers.openSafari.postMessage(urlOrObject)
/// `open` is an alias with the same behavior: open an HTTPS URL externally.
enum StartupScriptBridge {
    static let names = ["openSafari", "open"]

    static func externalURL(from body: Any) -> URL? {
        if let string = body as? String { return normalizedURL(string) }
        guard let payload = body as? [String: Any] else { return nil }
        return ["url", "href", "link", "target"]
            .compactMap { payload[$0] as? String }
            .compactMap { normalizedURL($0) }
            .first
    }

    private static func normalizedURL(_ raw: String) -> URL? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if value.hasPrefix("//") { return StartupConfiguration.webURL("https:" + value) }
        if let url = StartupConfiguration.webURL(value) { return url }
        // Never reinterpret an explicit unsupported scheme as an HTTPS hostname.
        guard URL(string: value)?.scheme == nil, !value.hasPrefix("/"), value.contains(".") else { return nil }
        return StartupConfiguration.webURL("https://" + value)
    }
}
