import SwiftUI

private struct NetworkTool: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
}

private let networkTools: [NetworkTool] = [
    NetworkTool(id: "wifi",   title: "WiFi Scanner",  subtitle: "Inspect the connected network — SSID, BSSID, security", icon: "wifi",                          color: .cyberGreen),
    NetworkTool(id: "subnet", title: "Subnet Sweep",  subtitle: "Discover live hosts across your local /24",            icon: "network",                       color: .cyberCyan),
    NetworkTool(id: "ports",  title: "Port Checker",  subtitle: "TCP-connect scan against a target host",                icon: "scope",                         color: .orange),
    NetworkTool(id: "status", title: "Network Status", subtitle: "VPN, proxy and Tor routing detection",                 icon: "shield.lefthalf.filled",        color: .cyberMagenta),
]

struct NetworkHubView: View {
    var body: some View {
        NavigationView {
            ZStack {
                Color.cyberBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        header
                        ForEach(networkTools) { tool in
                            NavigationLink {
                                destination(for: tool.id)
                            } label: {
                                toolCard(tool)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Network")
            .navigationBarTitleDisplayMode(.large)
        }
        .navigationViewStyle(.stack)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 22))
                .foregroundColor(.cyberGreen)
                .neonGlow(.cyberGreen, radius: 6)
            VStack(alignment: .leading, spacing: 2) {
                Text("Network Intelligence")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text("Live reconnaissance from this device")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.cyberGreen.opacity(0.7))
            }
            Spacer()
        }
        .padding()
        .background(Color.cyberSurface)
        .cornerRadius(10)
    }

    private func toolCard(_ tool: NetworkTool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(tool.color.opacity(0.15)).frame(width: 46, height: 46)
                Image(systemName: tool.icon).font(.system(size: 19)).foregroundColor(tool.color)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(tool.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(tool.subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.45))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(14)
        .background(Color.cyberSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyberBorder, lineWidth: 1))
    }

    @ViewBuilder
    private func destination(for id: String) -> some View {
        switch id {
        case "wifi":   WiFiScannerView()
        case "subnet": SubnetSweepView()
        case "ports":  PortCheckerView()
        case "status": NetworkStatusView()
        default:       EmptyView()
        }
    }
}
