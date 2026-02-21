import Foundation
import Combine
import WebKit

/// Manages Cloudflare Turnstile CAPTCHA token retrieval.
/// Loads a hosted Turnstile page in a visible WKWebView overlay so the widget
/// renders with a real origin (required by Cloudflare).
@MainActor
class TurnstileService: NSObject, ObservableObject {
    static let shared = TurnstileService()

    /// URL of the hosted Turnstile page served by your backend
    private static let turnstileURL: URL = {
        #if DEBUG && targetEnvironment(simulator)
        return URL(string: "http://localhost:3002/turnstile")!
        #else
        return URL(string: "https://api.remic.app/turnstile")!
        #endif
    }()

    @Published var isVerifying = false

    private var webView: WKWebView?
    private var overlayView: UIView?
    private var continuation: CheckedContinuation<String, Error>?
    /// Track whether the initial page load succeeded
    private var pageLoaded = false

    private override init() {
        super.init()
    }

    // MARK: - Public

    /// Request a Turnstile token. Shows a verification overlay, then returns the token.
    func getToken() async throws -> String {
        isVerifying = true
        defer { isVerifying = false }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.pageLoaded = false
            showTurnstile()
        }
    }

    // MARK: - Private

    private func showTurnstile() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            continuation?.resume(throwing: TurnstileError.noWindow)
            continuation = nil
            return
        }

        // Semi-transparent overlay
        let overlay = UIView(frame: window.bounds)
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.overlayView = overlay

        // Card container
        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 16
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(card)

        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            card.widthAnchor.constraint(equalToConstant: 340),
            card.heightAnchor.constraint(equalToConstant: 320)
        ])

        // "Verifying..." label
        let label = UILabel()
        label.text = L("Verifying you're human...")
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16)
        ])

        // Cancel button
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle(L("Cancel"), for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        cancelButton.setTitleColor(.systemRed, for: .normal)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        card.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            cancelButton.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            cancelButton.centerXAnchor.constraint(equalTo: card.centerXAnchor)
        ])

        // WKWebView
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        contentController.add(self, name: "turnstile")
        config.userContentController = contentController

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = self
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.isScrollEnabled = false
        wv.translatesAutoresizingMaskIntoConstraints = false
        self.webView = wv
        card.addSubview(wv)

        NSLayoutConstraint.activate([
            wv.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 12),
            wv.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            wv.bottomAnchor.constraint(equalTo: cancelButton.topAnchor, constant: -8)
        ])

        window.addSubview(overlay)

        // Load the hosted Turnstile page
        let request = URLRequest(url: Self.turnstileURL)
        wv.load(request)

        // Timeout after 60 seconds
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 60_000_000_000)
            if let c = self.continuation {
                self.continuation = nil
                self.cleanup()
                c.resume(throwing: TurnstileError.timeout)
            }
        }
    }

    @objc private func cancelTapped() {
        guard let c = continuation else { return }
        continuation = nil
        cleanup()
        c.resume(throwing: TurnstileError.cancelled)
    }

    private func cleanup() {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "turnstile")
        webView?.removeFromSuperview()
        webView = nil

        UIView.animate(withDuration: 0.2) {
            self.overlayView?.alpha = 0
        } completion: { _ in
            self.overlayView?.removeFromSuperview()
            self.overlayView = nil
        }
    }
}

// MARK: - WKScriptMessageHandler

extension TurnstileService: WKScriptMessageHandler {
    nonisolated func userContentController(_ userContentController: WKUserContentController,
                                           didReceive message: WKScriptMessage) {
        let rawBody = (message as NSObject).value(forKey: "body")
        Task { @MainActor in
            guard let body = rawBody as? String,
                  let data = body.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                  let type = json["type"],
                  let value = json["value"] else {
                return
            }

            switch type {
            case "token":
                // Success — dismiss and return the token
                guard let c = self.continuation else { return }
                self.continuation = nil
                self.cleanup()
                c.resume(returning: value)

            case "error":
                // Turnstile challenge error — log it but do NOT dismiss.
                // The widget handles retries internally.
                print("[Turnstile] Challenge error (widget will retry): \(value)")

            case "log":
                print("[Turnstile] JS: \(value)")

            default:
                break
            }
        }
    }
}

// MARK: - WKNavigationDelegate

extension TurnstileService: WKNavigationDelegate {
    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            self.pageLoaded = true
            print("[Turnstile] Page loaded")
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        // Only fail if the initial page hasn't loaded yet.
        // After the page loads, Turnstile may trigger sub-navigations that can fail — ignore those.
        Task { @MainActor in
            guard !self.pageLoaded else {
                print("[Turnstile] Post-load navigation error (ignored): \(error.localizedDescription)")
                return
            }
            guard let c = self.continuation else { return }
            self.continuation = nil
            self.cleanup()
            c.resume(throwing: TurnstileError.webViewFailed(error.localizedDescription))
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            guard let c = self.continuation else { return }
            self.continuation = nil
            self.cleanup()
            c.resume(throwing: TurnstileError.webViewFailed(error.localizedDescription))
        }
    }
}

// MARK: - Errors

enum TurnstileError: LocalizedError {
    case timeout
    case cancelled
    case noWindow
    case challengeFailed(String)
    case webViewFailed(String)

    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Verification timed out. Please try again."
        case .cancelled:
            return "Verification cancelled."
        case .noWindow:
            return "Unable to present verification."
        case .challengeFailed(let msg):
            return "Verification failed: \(msg)"
        case .webViewFailed(let msg):
            return "Verification error: \(msg)"
        }
    }
}
