import UIKit
import WebKit

final class StartupWebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    private let initialURL: URL
    private let store: StartupURLStore?
    private let userContentController = WKUserContentController()
    private lazy var webView: WKWebView = {
        let handler = StartupWeakScriptMessageHandler(target: self)
        StartupScriptBridge.names.forEach { userContentController.add(handler, name: $0) }
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController = userContentController
        return WKWebView(frame: .zero, configuration: configuration)
    }()
    private var entered = false
    var onClose: (() -> Void)?

    init(url: URL, store: StartupURLStore?) {
        initialURL = url
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    deinit {
        StartupScriptBridge.names.forEach { userContentController.removeScriptMessageHandler(forName: $0) }
    }

    required init?(coder: NSCoder) { fatalError("Use init(url:store:)") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(retry))
        if onClose != nil {
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(close))
        }
        webView.load(URLRequest(url: initialURL))
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !entered {
            entered = true
            store?.save(initialURL)
        }
    }

    @objc private func close() { dismiss(animated: true, completion: onClose) }
    @objc private func retry() {
        webView.load(URLRequest(url: webView.url ?? initialURL))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let url = webView.url { store?.save(url) }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url,
              StartupConfiguration.webURL(url.absoluteString) != nil else {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url,
           StartupConfiguration.webURL(url.absoluteString) != nil {
            webView.load(navigationAction.request)
        }
        return nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showError(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showError(error)
    }

    private func showError(_ error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled, presentedViewController == nil else { return }
        let alert = UIAlertController(title: "Unable to Load Page", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Retry", style: .default) { [weak self] _ in self?.retry() })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}


extension StartupWebViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.webView === webView,
              StartupScriptBridge.names.contains(message.name),
              let url = StartupScriptBridge.externalURL(from: message.body) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}

/// WKUserContentController retains handlers; the weak target prevents a controller retain cycle.
private final class StartupWeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?

    init(target: WKScriptMessageHandler) { self.target = target }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
