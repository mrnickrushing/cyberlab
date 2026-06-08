import SwiftUI

struct NetworkStatusView: View {
    @StateObject private var detector = VPNDetector()

    var body: some View {
        ZStack {
            Color.cyberBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    header
                    statusCard(
                        title: "VPN Tunnel",
                        icon: "lock.shield.fill",
                        active: detector.status.vpnActive,
                        activeText: "Active",
                        inactiveText: "Inactive",
                        detail: detector.status.vpnActive ? "Traffic is routed through a VPN interface (utun/ipsec)." : "No VPN tunnel interface detected."
                    )
                    statusCard(
                        title: "Proxy",
                        icon: "arrow.triangle.swap",
                        active: detector.status.proxyDetected,
                        activeText: "Detected",
                        inactiveText: "None",
                        detail: detector.status.proxyDetected
                            ? "System proxy configured" + (detector.status.proxyHost.map { ": \($0)" } ?? ".")
                            : "No system HTTP/HTTPS proxy configured."
                    )
                    torCard
                    refreshButton
                }
                .padding(16)
            }
        }
        .navigationTitle("Network Status")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { detector.refresh() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 20))
                .foregroundColor(.cyberGreen)
                .neonGlow(.cyberGreen, radius: 5)
            VStack(alignment: .leading, spacing: 2) {
                Text("Anonymity & Routing")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text("VPN · Proxy · Tor detection")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.cyberGreen.opacity(0.7))
            }
            Spacer()
            if detector.isChecking {
                ProgressView().tint(.cyberGreen).scaleEffect(0.8)
            }
        }
        .padding()
        .background(Color.cyberSurface)
        .cornerRadius(10)
    }

    private func statusCard(title: String, icon: String, active: Bool, activeText: String, inactiveText: String, detail: String) -> some View {
        let color: Color = active ? .cyberGreen : .white.opacity(0.4)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text(active ? activeText : inactiveText)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .kerning(0.5)
                    .foregroundColor(active ? .black : .white.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(active ? Color.cyberGreen : Color.cyberBackground)
                    .cornerRadius(4)
            }
            Text(detail)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.45))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color.cyberSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(active ? Color.cyberGreen.opacity(0.35) : Color.cyberBorder, lineWidth: 1))
    }

    private var torCard: some View {
        let tor = detector.status.torLikely
        let checked = detector.status.checkedTor
        let color: Color = tor ? .cyberMagenta : .white.opacity(0.4)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 18))
                    .foregroundColor(color)
                Text("Tor Network")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text(checked ? (tor ? "Detected" : "Not Detected") : "Checking…")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(tor ? .black : .white.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(tor ? Color.cyberMagenta : Color.cyberBackground)
                    .cornerRadius(4)
            }
            Text(checked
                 ? (tor ? "Your exit appears to be a Tor node (check.torproject.org)." : "Traffic does not appear to exit via Tor.")
                 : "Querying check.torproject.org…")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.45))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color.cyberSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(tor ? Color.cyberMagenta.opacity(0.4) : Color.cyberBorder, lineWidth: 1))
    }

    private var refreshButton: some View {
        Button {
            HapticFeedback.statusChange()
            detector.refresh()
        } label: {
            Label("Re-check Network Status", systemImage: "arrow.clockwise")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.cyberGreen)
                .cornerRadius(10)
        }
        .disabled(detector.isChecking)
    }
}
