import SwiftUI

struct SubnetSweepView: View {
    @StateObject private var scanner = SubnetScanner()

    var body: some View {
        ZStack {
            Color.cyberBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                headerCard
                if !scanner.isOnWiFi && scanner.localIP == nil {
                    wifiWarning
                }
                progressBar
                resultsList
                controlBar
            }
        }
        .navigationTitle("Subnet Sweep")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "network")
                    .font(.system(size: 18))
                    .foregroundColor(.cyberGreen)
                VStack(alignment: .leading, spacing: 2) {
                    Text(scanner.subnetBase.map { "\($0).0/24" } ?? "Local Subnet /24")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                    Text(scanner.localIP.map { "This device: \($0)" } ?? "Tap Scan to discover hosts")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.cyberGreen.opacity(0.7))
                }
                Spacer()
                Text("\(scanner.hosts.count) up")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyberGreen)
            }
        }
        .padding()
        .background(Color.cyberSurface)
    }

    private var wifiWarning: some View {
        Label("Not connected to WiFi — subnet sweep requires a local network (en0).", systemImage: "exclamationmark.triangle.fill")
            .font(.system(size: 11))
            .foregroundColor(.orange)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.12))
    }

    private var progressBar: some View {
        VStack(spacing: 2) {
            ProgressView(value: scanner.progress)
                .tint(.cyberGreen)
            if scanner.isScanning {
                HStack {
                    Text("Probing \(scanner.scannedCount)/254")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                    Spacer()
                    Text("\(Int(scanner.progress * 100))%")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.cyberGreen.opacity(0.7))
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                columnHeader
                ForEach(scanner.hosts) { host in
                    hostRow(host)
                }
                if scanner.hosts.isEmpty && !scanner.isScanning {
                    Text("No hosts discovered yet")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.top, 40)
                }
            }
            .padding(.horizontal)
        }
    }

    private var columnHeader: some View {
        HStack {
            Text("IP ADDRESS")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("RESP")
                .frame(width: 70, alignment: .trailing)
            Text("STATUS")
                .frame(width: 60, alignment: .trailing)
        }
        .font(.system(size: 9, weight: .bold, design: .monospaced))
        .foregroundColor(.white.opacity(0.35))
        .padding(.vertical, 6)
    }

    private func hostRow(_ host: SubnetHost) -> some View {
        HStack {
            Text(host.ip)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.cyberGreen)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            Text(host.responseMs.map { "\($0)ms" } ?? "—")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 70, alignment: .trailing)
            Text(host.isUp ? "UP" : "DOWN")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(host.isUp ? .cyberGreen : .red)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.vertical, 7)
        .overlay(Rectangle().fill(Color.cyberBorder.opacity(0.4)).frame(height: 1), alignment: .bottom)
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            if scanner.isScanning {
                Button(role: .destructive) {
                    HapticFeedback.statusChange()
                    scanner.stop()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.85))
                        .cornerRadius(10)
                }
            } else {
                Button {
                    HapticFeedback.scanLaunch()
                    scanner.start()
                } label: {
                    Label("Scan Subnet", systemImage: "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.cyberGreen)
                        .cornerRadius(10)
                        .neonGlow(.cyberGreen, radius: 6)
                }
            }
        }
        .padding()
        .background(Color.cyberSurface)
    }
}
