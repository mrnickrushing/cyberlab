import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showCommandPalette = false
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
        .overlay(alignment: .bottomTrailing) {
            Button {
                showCommandPalette = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(width: 52, height: 52)
                    .background(Color.cyberGreen)
                    .clipShape(Circle())
                    .neonGlow(.cyberGreen, radius: 8)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 64)
        }
        .sheet(isPresented: $showCommandPalette) {
            CommandPaletteView()
        }
        .animation(.easeInOut(duration: 0.3), value: networkMonitor.isConnected)
    }
}
