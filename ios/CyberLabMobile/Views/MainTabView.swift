import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var networkMonitor: NetworkMonitor

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "gauge.with.dots.needle.bottom.50percent") }
                .tag(0)

            TargetsView()
                .tabItem { Label("Targets", systemImage: "target") }
                .tag(1)

            ScansView()
                .tabItem { Label("Scans", systemImage: "scanner") }
                .tag(2)

            NetworksView()
                .tabItem { Label("Networks", systemImage: "network") }
                .tag(3)

            FindingsView()
                .tabItem { Label("Findings", systemImage: "exclamationmark.triangle") }
                .tag(4)

            ReportsView()
                .tabItem { Label("Reports", systemImage: "doc.text.magnifyingglass") }
                .tag(5)

            AIAssistantView()
                .tabItem { Label("AI", systemImage: "brain.head.profile") }
                .tag(6)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(7)
        }
        .tint(.cyberGreen)
        .overlay(alignment: .top) {
            if !networkMonitor.isConnected {
                OfflineBanner()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: networkMonitor.isConnected)
    }
}
