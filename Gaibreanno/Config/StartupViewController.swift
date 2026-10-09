import UIKit

final class StartupViewController: UIViewController {
    private let service = StartupService()
    private let store = StartupURLStore()
    private var privacyURL = StartupConfiguration.defaultPrivacyURL
    private var destinationURL: URL?
    private var ready = false
    private var started = false
    private var prompt: UIAlertController?
    private var continueAction: UIAlertAction?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Reuse the actual launch storyboard so artwork, crop and background stay identical.
        let launch = UIStoryboard(name: "LaunchScreen", bundle: nil).instantiateInitialViewController()!
        addChild(launch)
        launch.view.frame = view.bounds
        launch.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(launch.view)
        launch.didMove(toParent: self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !started else { return }
        started = true
        showPrompt()
        service.fetchURL { [weak self] url in
            guard let self else { return }
            if let url {
                if StartupConfiguration.isPrivacyURL(url) {
                    self.privacyURL = url
                } else {
                    self.store.saveAPIURL(url)
                }
            }
            self.destinationURL = StartupConfiguration.destinationURL(receivedURL: url, cachedURL: self.store.lastURL)
            self.ready = true
            self.updatePrompt()
        }
    }

    private var promptMessage: String {
        if !ready { return "Please review our Privacy Policy. Connecting…" }
        return "Please review our Privacy Policy before continuing to Time Cards."
    }

    private func updatePrompt() {
        prompt?.message = promptMessage
        continueAction?.isEnabled = ready
    }

    private func showPrompt() {
        let alert = UIAlertController(title: "Privacy Policy", message: promptMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "View Privacy Policy", style: .default) { [weak self] _ in
            self?.showPrivacy()
        })
        let confirm = UIAlertAction(title: "Continue", style: .default) { [weak self] _ in
            self?.enterApplication()
        }
        confirm.isEnabled = ready
        alert.addAction(confirm)
        prompt = alert
        continueAction = confirm
        present(alert, animated: true)
    }

    private func showPrivacy() {
        let policy = StartupWebViewController(url: privacyURL)
        policy.title = "Privacy Policy"
        policy.onClose = { [weak self] in self?.showPrompt() }
        let navigation = UINavigationController(rootViewController: policy)
        navigation.modalPresentationStyle = .fullScreen
        present(navigation, animated: true)
    }

    private func enterApplication() {
        guard ready, let window = view.window else { return }
        PushNotificationManager.shared.requestAuthorizationAndRegister()
        if let destinationURL {
            let browser = StartupWebViewController(url: destinationURL)
            window.rootViewController = browser
        } else {
            window.rootViewController = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController()
        }
    }
}
