import SwiftUI
import UserNotifications

@main
struct DreamCatcherApp: App {
    @StateObject var store = DreamStore()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var landingOpacity: Double = 1.0
    @State private var landingFinished = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(store)
                    .onAppear {
                        _ = NotificationManager.shared
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

