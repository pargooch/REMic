import SwiftUI
import UserNotifications

@main
struct REMicApp: App {
    @StateObject var store = DreamStore()
    @StateObject private var authManager = AuthManager.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var landingOpacity: Double = 1.0
    @State private var landingFinished = false
    @State private var analysisService = DreamAnalysisService()
    @State private var toastMessage: String?
    @State private var toastIsError = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if authManager.isAuthenticated {
                        MainTabView()
                    } else {
                        NavigationStack {
                            AuthView()
                        }
                    }
                }
                .environmentObject(store)
                .environment(analysisService)
                .onAppear {
                    _ = NotificationManager.shared
                    KeyboardDismissHelper.setupGlobalDoneButton()
                    KeyboardDismissHelper.setupTapToDismiss()
                }

                if !landingFinished {
                    LandingAnimationView {
                        withAnimation(.easeOut(duration: 2.0)) {
                            landingOpacity = 0
                        } completion: {
                            landingFinished = true
                        }
                    }
                    .opacity(landingOpacity)
                    .zIndex(1)
                }

                // Toast overlay
                if let message = toastMessage {
                    VStack {
                        Text(message)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(toastIsError ? Color.red : Color.green)
                            )
                            .padding(.top, 60)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(2)
                }
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                if let url = activity.webpageURL {
                    handleDeepLink(url)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { await AuthManager.shared.refreshUser() }
                }
            }
        }
    }
    // MARK: - Deep Link Handling

    private func handleDeepLink(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return }

        // Handle both remic://verify and https://api.remic.app/api/auth/verify-email
        let isVerifyScheme = url.scheme == "remic" && url.host == "verify"
        let isVerifyUniversal = url.host == "api.remic.app" && url.path.contains("/auth/verify-email")

        guard isVerifyScheme || isVerifyUniversal else { return }

        let params = Dictionary(uniqueKeysWithValues:
            (components.queryItems ?? []).compactMap { item in
                item.value.map { (item.name, $0) }
            }
        )

        let status = params["status"]
        let message = params["message"]

        if status == "success" {
            showToast(L("Email verified successfully!"), isError: false)
            Task { await AuthManager.shared.refreshUser() }
        } else if status == "error" {
            showToast(message ?? L("Verification failed"), isError: true)
        }
    }

    private func showToast(_ message: String, isError: Bool) {
        toastIsError = isError
        withAnimation(.spring(response: 0.4)) {
            toastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeOut) {
                toastMessage = nil
            }
        }
    }
}

// MARK: - Keyboard Dismissal (UIKit-based for reliability)

enum KeyboardDismissHelper {

    /// Adds a localized "Done" button above the keyboard for all UITextField and UITextView instances.
    static func setupGlobalDoneButton() {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(title: L("Done"), style: .done, target: nil, action: #selector(UIApplication.dismissKeyboard))
        toolbar.items = [spacer, doneButton]

        UITextView.appearance().inputAccessoryView = toolbar
    }

    /// Adds a tap gesture recognizer on the key window that dismisses the keyboard
    /// without interfering with buttons, links, or other interactive elements.
    static func setupTapToDismiss() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else { return }
        let tap = UITapGestureRecognizer(target: window, action: #selector(UIView.endEditing(_:)))
        tap.cancelsTouchesInView = false
        tap.requiresExclusiveTouchType = false
        window.addGestureRecognizer(tap)
    }
}

private extension UIApplication {
    @objc static func dismissKeyboard() {
        shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if let dreamIdString = userInfo["dreamId"] as? String,
           let _ = UUID(uuidString: dreamIdString) {
            // Could navigate to specific dream here
            // For now, just open the app
        }

        completionHandler()
    }
}

