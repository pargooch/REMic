import SwiftUI
import UserNotifications

@main
struct REMicApp: App {
    @StateObject var store = DreamStore()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var landingOpacity: Double = 1.0
    @State private var landingFinished = false
    @State private var analysisService = DreamAnalysisService()

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
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

        UITextField.appearance().inputAccessoryView = toolbar
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

