import SwiftUI

extension Notification.Name {
    static let showCommandPalette = Notification.Name("ShowCommandPalette")
}

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

            KaliTerminalWrapperView()
                .tabItem { Label("Terminal", systemImage: "terminal") }
                .tag(3)

            MoreMenuView()
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
                .tag(4)
        }
        .tint(.cyberGreen)
        .overlay(alignment: .top) {
            if !networkMonitor.isConnected {
                OfflineBanner()
            }
        }
        .sheet(isPresented: $showCommandPalette) {
            CommandPaletteView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .showCommandPalette)) { _ in
            showCommandPalette = true
        }
        .animation(.easeInOut(duration: 0.3), value: networkMonitor.isConnected)
    }
}
