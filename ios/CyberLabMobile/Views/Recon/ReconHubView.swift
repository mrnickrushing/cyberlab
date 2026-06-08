import SwiftUI

private struct ReconTool: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
}

private let reconTools: [ReconTool] = [
    ReconTool(id: "ct",      title: "Cert Transparency", subtitle: "Enumerate subdomains from CT logs (crt.sh)",   icon: "lock.shield",            color: .cyberGreen),
    ReconTool(id: "headers", title: "HTTP Headers",      subtitle: "Grade a site's security response headers",     icon: "doc.text.magnifyingglass", color: .cyberCyan),
    ReconTool(id: "pdns",    title: "Passive DNS",        subtitle: "Current records and historical host mappings",  icon: "globe.americas",         color: .orange),
    ReconTool(id: "revip",   title: "Reverse IP",         subtitle: "Find all domains sharing an IP address",        icon: "arrow.triangle.swap",    color: .cyberMagenta),
    ReconTool(id: "whois",   title: "WHOIS",              subtitle: "Domain registration and ownership data",        icon: "person.text.rectangle",  color: .cyberGreen),
    ReconTool(id: "cve",     title: "CVE Search",         subtitle: "Search the NIST vulnerability database",        icon: "ant.circle",             color: .red),
]

private let toolsTools: [ReconTool] = [
    ReconTool(id: "pentest", title: "Pentest Checklists", subtitle: "OWASP, network and mobile assessment tracking", icon: "checklist",              color: .cyberCyan),
    ReconTool(id: "ssh",     title: "SSH Terminal",       subtitle: "Build and copy SSH connection commands",        icon: "terminal",               color: .cyberGreen),
]

struct ReconHubView: View {
    var body: some View {
        NavigationView {
            ZStack {
                Color.cyberBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        header
                        sectionLabel("RECON")
                        ForEach(reconTools) { tool in
                            NavigationLink { destination(for: tool.id) } label: { toolCard(tool) }
                                .buttonStyle(.plain)
                        }
                        sectionLabel("TOOLS")
                        ForEach(toolsTools) { tool in
                            NavigationLink { destination(for: tool.id) } label: { toolCard(tool) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Recon")
            .navigationBarTitleDisplayMode(.large)
        }
        .navigationViewStyle(.stack)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 22))
                .foregroundColor(.cyberGreen)
                .neonGlow(.cyberGreen, radius: 6)
            VStack(alignment: .leading, spacing: 2) {
                Text("Recon & Intelligence")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text("OSINT, fingerprinting and vulnerability lookups")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.cyberGreen.opacity(0.7))
            }
            Spacer()
        }
        .padding()
        .background(Color.cyberSurface)
        .cornerRadius(10)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundColor(.cyberGreen.opacity(0.6))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }

    private func toolCard(_ tool: ReconTool) -> some View {
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
        case "ct":      CertTransparencyView()
        case "headers": HTTPHeadersView()
        case "pdns":    PassiveDNSView()
        case "revip":   ReverseIPView()
        case "whois":   WHOISView()
        case "cve":     CVESearchView()
        case "pentest": PentestChecklistHubView()
        case "ssh":     SSHTerminalView()
        default:        EmptyView()
        }
    }
}
