import SwiftUI

struct ScanDetailView: View {
    let scanId: String
    @State private var scan: ScanJob?
    @State private var result: ScanResult?
    @State private var isLoading = true
    @State private var error: String?
    @State private var showRaw = false
    @State private var refreshTimer: Timer?
    private let client = APIClient.shared

    var body: some View {
        ZStack {
            Color.cyberBackground.ignoresSafeArea()
            if isLoading {
                ProgressView().tint(.cyberGreen)
            } else if let error {
                ErrorView(message: error) { Task { await loadData() } }
            } else if let scan {
                ScrollView {
                    VStack(spacing: 16) {
                        // Job card
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("[\(scan.tool.uppercased())]")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(.cyberGreen)
                                Spacer()
                                StatusBadge(text: scan.status.label, color: scan.status.color)
                            }
                            if scan.status.isActive {
                                ProgressView(value: Double(scan.progress ?? 0), total: 100)
                                    .tint(.cyberGreen)
                                    .background(Color.cyberBorder)
                                Text("Progress: \(scan.progress ?? 0)%")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            Divider().background(Color.cyberBorder)
                            InfoRow(label: "Started", value: scan.startedAt?.formattedFullDate ?? "Pending")
                            if let completed = scan.completedAt {
                                InfoRow(label: "Completed", value: completed.formattedFullDate)
                            }
                            if let flags = scan.flags, !flags.isEmpty {
                                InfoRow(label: "Flags", value: flags)
                            }
                            if let errMsg = scan.errorMessage {
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red).font(.caption)
                                    Text(errMsg).font(.system(size: 12)).foregroundColor(.red.opacity(0.8))
                                }
                            }
                        }
                        .cyberCard()

                        // Parsed results
                        if let hosts = result?.parsedData?.hosts, !hosts.isEmpty {
                            ParsedResultsCard(hosts: hosts)
                        }

                        // Raw output toggle
                        if let raw = result?.rawOutput, !raw.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Button {
                                    withAnimation { showRaw.toggle() }
                                } label: {
                                    HStack {
                                        Text("Raw Output")
                                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                            .foregroundColor(.white)
                                        Spacer()
                                        Image(systemName: showRaw ? "chevron.up" : "chevron.down")
                                            .foregroundColor(.white.opacity(0.4))
                                    }
                                }
                                if showRaw {
                                    ScrollView(.horizontal) {
                                        Text(raw)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(.cyberGreen.opacity(0.9))
                                            .textSelection(.enabled)
                                    }
                                }
                            }
                            .cyberCard()
                        }

                        if scan.status.isActive {
                            Button("Cancel Scan") {
                                Task {
                                    try? await client.requestVoid(Endpoints.cancelScan(scanId))
                                    await loadData()
                                }
                            }
                            .foregroundColor(.orange)
                            .padding()
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.5), lineWidth: 1))
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Scan Detail")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadData() }
        .onAppear { startPolling() }
        .onDisappear { stopPolling() }
    }

    private func loadData() async {
        do {
            async let s: ScanJob = client.request(Endpoints.scan(scanId))
            async let r: ScanResult? = try? client.request(Endpoints.scanResults(scanId))
            scan = try await s
            result = await r
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }

    private func startPolling() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
            if scan?.status.isActive == true { Task { await loadData() } }
        }
    }
    private func stopPolling() { refreshTimer?.invalidate(); refreshTimer = nil }
}

struct ParsedResultsCard: View {
    let hosts: [NmapHost]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Parsed Results — \(hosts.count) host(s)")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
            ForEach(Array(hosts.enumerated()), id: \.offset) { _, host in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(host.address ?? "Unknown")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyberGreen)
                        Spacer()
                        StatusBadge(
                            text: (host.status ?? "unknown").uppercased(),
                            color: host.status == "up" ? .cyberGreen : .gray
                        )
                    }
                    if let hostname = host.hostname {
                        Text(hostname).font(.system(size: 11)).foregroundColor(.white.opacity(0.5))
                    }
                    if let os = host.os {
                        Label(os, systemImage: "desktopcomputer")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    if let ports = host.ports, !ports.isEmpty {
                        Divider().background(Color.cyberBorder)
                        ForEach(ports, id: \.port) { port in
                            HStack {
                                Text("\(port.port)/\(port.protocol ?? "tcp")")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(port.state == "open" ? .cyberGreen : .gray)
                                    .frame(width: 80, alignment: .leading)
                                Text(port.service ?? "")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.7))
                                Spacer()
                                if let product = port.product {
                                    Text(product)
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                            }
                        }
                    }
                }
                .padding(10)
                .background(Color.cyberBackground)
                .cornerRadius(8)
            }
        }
        .cyberCard()
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
                .textSelection(.enabled)
        }
    }
}
