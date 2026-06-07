import SwiftUI
import UserNotifications

@main
struct CyberLabMobileApp: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var biometricManager = BiometricAuthManager()
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(biometricManager)
                .environmentObject(APIClient.shared)
                .preferredColorScheme(.dark)
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        requestNotificationPermission()
        return true
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { await DeviceTokenManager.shared.register(token: token) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[APNs] Failed to register: \(error.localizedDescription)")
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}

@MainActor
final class DeviceTokenManager {
    static let shared = DeviceTokenManager()
    private let tokenKey = "cyberlab_device_token"

    func register(token: String) async {
        let stored = UserDefaults.standard.string(forKey: tokenKey)
        guard token != stored else { return }
        let req = RegisterDeviceRequest(deviceToken: token, label: UIDevice.current.name)
        if (try? await APIClient.shared.request(Endpoints.registerDevice(req)) as EmptyResponse?) != nil {
            UserDefaults.standard.set(token, forKey: tokenKey)
        }
    }
}


