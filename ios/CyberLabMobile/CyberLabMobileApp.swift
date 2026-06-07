import SwiftUI

@main
struct CyberLabMobileApp: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var biometricManager = BiometricAuthManager()

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
