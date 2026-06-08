import SwiftUI

struct WiFiScannerView: View {
    @StateObject private var scanner = WiFiScanner()
    @State private var showScanAlert = false

    var body: some View {
        ZStack {
            Color.cyberBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    header
                    if scanner.isScanning {
                        scanningCard
                    } else if let net = scanner.current {
                        currentNetworkCard(net)
                    } else {
                        emptyCard
                    }
                    scanButton
                    infoFooter
                }
                .padding(16)
            }
        }
        .navigationTitle("WiFi Scanner")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { scanner.refresh() }
        .alert("Nearby Network Scan", isPresented: $showScanAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("A full scan of nearby WiFi networks requires the NEHotspotHelper entitlement, which Apple grants only by special request. CyberLab instead reports your current connected network in detail below.")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi")
                .font(.system(size: 20))
                .foregroundColor(.cyberGreen)
                .neonGlow(.cyberGreen, radius: 5)
            VStack(alignment: .leading, spacing: 2) {
                Text("WiFi Intelligence")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text("Current network analysis")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.cyberGreen.opacity(0.7))
            }
            Spacer()
            if let last = scanner.lastScan {
                Text(last, style: .time)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .padding()
        .background(Color.cyberSurface)
        .cornerRadius(10)
    }

    private var scanningCard: some View {
        VStack(spacing: 12) {
            ProgressView().tint(.cyberGreen)
            Text("Reading current network…")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .cyberCard()
    }

    private func currentNetworkCard(_ net: WiFiNetworkInfo) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "wifi")
                    .font(.system(size: 26))
                    .foregroundColor(.cyberGreen)
                    .pulsingGlow(.cyberGreen)
                VStack(alignment: .leading, spacing: 2) {
                    Text(net.ssid)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .textSelection(.enabled)
                    Text("CONNECTED")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .kerning(1)
                        .foregroundColor(.cyberGreen)
                }
                Spacer()
            }

            Divider().background(Color.cyberBorder)

            kv("SSID", net.ssid)
            kv("BSSID", net.bssid ?? "Hidden (requires entitlement)")
            kv("Security", net.securityType)
            if let rssi = net.signalStrength {
                signalRow(rssi)
            } else {
                kv("Signal", "Unavailable")
            }
        }
        .padding()
        .background(Color.cyberSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyberGreen.opacity(0.35), lineWidth: 1))
    }

    private var emptyCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 30))
                .foregroundColor(.red.opacity(0.7))
            Text(scanner.errorMessage ?? "No WiFi network detected")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.red.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .cyberCard()
    }

    private var scanButton: some View {
        VStack(spacing: 10) {
            Button {
                HapticFeedback.statusChange()
                scanner.refresh()
            } label: {
                Label("Refresh Current Network", systemImage: "arrow.clockwise")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.cyberGreen)
                    .cornerRadius(10)
            }
            Button {
                HapticFeedback.statusChange()
                showScanAlert = true
            } label: {
                Label("Scan for Nearby Networks", systemImage: "dot.radiowaves.left.and.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.cyberCyan)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.cyberSurface)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyberCyan.opacity(0.4), lineWidth: 1))
            }
        }
    }

    private var infoFooter: some View {
        Text("iOS restricts WiFi scanning to the connected network unless the app holds the NEHotspotHelper entitlement. Security type is inferred from device capabilities.")
            .font(.system(size: 10))
            .foregroundColor(.white.opacity(0.3))
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func signalRow(_ rssi: Int) -> some View {
        let bars = signalBars(rssi)
        return HStack(alignment: .top, spacing: 8) {
            Text("Signal")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 88, alignment: .leading)
            HStack(spacing: 8) {
                Text("\(rssi) dBm")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(signalColor(rssi))
                HStack(spacing: 2) {
                    ForEach(0..<4) { i in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(i < bars ? signalColor(rssi) : Color.white.opacity(0.15))
                            .frame(width: 4, height: CGFloat(6 + i * 4))
                    }
                }
            }
            Spacer()
        }
    }

    private func signalBars(_ rssi: Int) -> Int {
        switch rssi {
        case ..<(-80): return 1
        case (-80)..<(-67): return 2
        case (-67)..<(-55): return 3
        default: return 4
        }
    }

    private func signalColor(_ rssi: Int) -> Color {
        switch rssi {
        case ..<(-80): return .red
        case (-80)..<(-67): return .orange
        default: return .cyberGreen
        }
    }

    private func kv(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 88, alignment: .leading)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
                .textSelection(.enabled)
            Spacer()
        }
    }
}
