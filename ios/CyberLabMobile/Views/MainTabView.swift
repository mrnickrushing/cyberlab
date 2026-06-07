import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "gauge.with.dots.needle.bottom.50percent")
                }
                .tag(0)

            TargetsView()
                .tabItem {
                    Label("Targets", systemImage: "target")
                }
                .tag(1)

            ScansView()
                .tabItem {
                    Label("Scans", systemImage: "scanner")
                }
                .tag(2)

            FindingsView()
                .tabItem {
                    Label("Findings", systemImage: "exclamationmark.triangle")
                }
                .tag(3)

            NotesView()
                .tabItem {
                    Label("Notes", systemImage: "note.text")
                }
                .tag(4)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(5)
        }
        .tint(.cyberGreen)
    }
}
