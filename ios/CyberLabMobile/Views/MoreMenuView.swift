import SwiftUI

struct MoreMenuView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    MoreMenuRow(icon: "network", label: "Networks", color: .cyan) {
                        NetworksView()
                    }
                    MoreMenuRow(icon: "antenna.radiowaves.left.and.right", label: "Network Scanner", color: .green) {
                        NetworkHubView()
                    }
                    MoreMenuRow(icon: "magnifyingglass.circle", label: "Recon Tools", color: .green) {
                        ReconHubView()
                    }
                } header: {
                    Text("TOOLS").font(.system(.caption, design: .monospaced)).foregroundColor(.cyberGreen)
                }

                Section {
                    MoreMenuRow(icon: "exclamationmark.triangle", label: "Findings", color: .orange) {
                        FindingsView()
                    }
                    MoreMenuRow(icon: "doc.text", label: "Reports", color: .blue) {
                        ReportsView()
                    }
                    MoreMenuRow(icon: "brain.head.profile", label: "AI Assistant", color: .purple) {
                        AIAssistantView()
                    }
                } header: {
                    Text("ANALYSIS").font(.system(.caption, design: .monospaced)).foregroundColor(.cyberGreen)
                }

                Section {
                    MoreMenuRow(icon: "gearshape", label: "Settings", color: .gray) {
                        SettingsView()
                    }
                } header: {
                    Text("SYSTEM").font(.system(.caption, design: .monospaced)).foregroundColor(.cyberGreen)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

private struct MoreMenuRow<Destination: View>: View {
    let icon: String
    let label: String
    let color: Color
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(color)
                }
                Text(label)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color(white: 0.1))
    }
}
