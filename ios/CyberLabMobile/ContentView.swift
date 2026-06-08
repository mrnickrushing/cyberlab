import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var bootComplete = false

    var body: some View {
        Group {
            if !bootComplete {
                BootSequenceView { withAnimation(.easeInOut(duration: 0.4)) { bootComplete = true } }
            } else if authManager.isAuthenticated {
                if !authManager.legalAcknowledged {
                    LegalWarningView()
                } else {
                    MainTabView()
                }
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
    }
}
