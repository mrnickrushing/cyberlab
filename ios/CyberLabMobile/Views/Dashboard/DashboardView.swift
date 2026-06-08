import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var stats: DashboardStats?
    @State private var isLoading = true
    @State private var error: String?
    @State private var showNewScan = false
    private let client = APIClient.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cyberBackground.ignoresSafeArea()
                if isLoading {
                    ProgressView().tint(.cyberGreen)
                } else if let error {
                    ErrorView(message: error) { Task { await loadData() } }
                } else if let stats {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Security Score
                            SecurityScoreCard(score: stats.securityScore)

                            // Stat Row
                            HStack(spacing: 12) {
                                StatCard(value: "\(stats.targetCount)", label: "Targets", icon: "target", color: .cyberGreen)
                                StatCard(value: "\(stats.activeScans)", label: "Active Scans", icon: "scanner", color: stats.activeScans > 0 ? .orange : .gray)
                                StatCard(value: "\(stats.openFindings)", label: "Open Findings", icon: "exclamationmark.triangle", color: stats.openFindings > 0 ? .red : .gray)
                            }

                            // Findings by Severity
                            FindingsBySeverityCard(data: stats.findingsBySeverity)

                            // Lab Health
                            LabHealthCard(health: stats.labHealth)

                            // Recent Scans
                            if !stats.recentScans.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Recent Scans")
                                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.6))
                                    ForEach(stats.recentScans) { scan in
                                        NavigationLink(destination: ScanDetailView(scanId: scan.id)) {
                                            RecentScanRow(scan: scan)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .cyberCard()
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showNewScan = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.cyberGreen)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { Task { await loadData() } } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.cyberGreen)
                    }
                }
            }
            .sheet(isPresented: $showNewScan) {
                NewScanSheet(onCreated: { Task { await loadData() } })
            }
        }
        .task { await loadData() }
    }

    private func loadData() async {
        isLoading = true
        error = nil
        do {
            stats = try await client.request(Endpoints.dashboard)
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Sub-components

struct SecurityScoreCard: View {
    let score: Int
    var color: Color {
        if score >= 80 { return .cyberGreen }
        else if score >= 60 { return .yellow }
        else if score >= 40 { return .orange }
        else { return .red }
    }
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Security Score")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                Text("\(score)")
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
                Text(scoreLabel)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(color.opacity(0.8))
            }
            Spacer()
            ZStack {
                Circle()
                    .stroke(Color.cyberBorder, lineWidth: 8)
                    .frame(width: 90, height: 90)
                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees(-90))
                    .neonGlow(color, radius: 6)
                Text("\(score)%")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
            }
        }
        .cyberCard()
        .hudFrame(color: color.opacity(0.6))
    }
    var scoreLabel: String {
        if score >= 80 { return "SECURE" }
        else if score >= 60 { return "MODERATE" }
        else if score >= 40 { return "AT RISK" }
        else { return "CRITICAL" }
    }
}

struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.cyberSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyberBorder, lineWidth: 1))
    }
}

struct FindingsBySeverityCard: View {
    let data: FindingsBySeverity
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Findings by Severity")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
            HStack(spacing: 8) {
                SeverityBar(label: "Critical", count: data.critical, color: FindingSeverity.critical.color)
                SeverityBar(label: "High", count: data.high, color: FindingSeverity.high.color)
                SeverityBar(label: "Medium", count: data.medium, color: FindingSeverity.medium.color)
                SeverityBar(label: "Low", count: data.low, color: FindingSeverity.low.color)
                SeverityBar(label: "Info", count: data.info, color: FindingSeverity.info.color)
            }
        }
        .cyberCard()
    }
}

struct SeverityBar: View {
    let label: String
    let count: Int
    let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(count > 0 ? color : .white.opacity(0.3))
            Rectangle()
                .fill(count > 0 ? color : Color.cyberBorder)
                .frame(height: 4)
                .cornerRadius(2)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }
}

struct LabHealthCard: View {
    let health: LabHealth
    var statusColor: Color { health.status == "healthy" ? .cyberGreen : .orange }
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Lab Health")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                HStack(spacing: 6) {
                    Circle().fill(statusColor).frame(width: 8, height: 8)
                    Text(health.status.uppercased())
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(statusColor)
                }
            }
            Spacer()
            HStack(spacing: 16) {
                HealthIndicator(label: "Worker", isOk: health.workerConnected)
                HealthIndicator(label: "DB", isOk: health.dbConnected)
            }
        }
        .cyberCard()
    }
}

struct HealthIndicator: View {
    let label: String
    let isOk: Bool
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: isOk ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isOk ? .cyberGreen : .red)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.4))
        }
    }
}

struct RecentScanRow: View {
    let scan: ScanJobWithTarget
    var body: some View {
        HStack {
            Image(systemName: "scanner")
                .font(.system(size: 14))
                .foregroundColor(scan.status.color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(scan.targetName ?? scan.targetAddress ?? "Unknown")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                Text("[\(scan.tool.uppercased())]")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.cyberGreen.opacity(0.7))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                StatusBadge(text: scan.status.label, color: scan.status.color)
                Text(scan.createdAt.formattedDate)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }
}

// MARK: - New Scan Sheet

struct NewScanSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    let onCreated: () -> Void

    @State private var targets: [Target] = []
    @State private var profiles: [ScanProfile] = []
    @State private var selectedTargetId = ""
    @State private var selectedTool = "nmap"
    @State private var customFlags = ""
    @State private var selectedProfileId = ""
    @State private var isLoading = false
    @State private var error = ""
    private let client = APIClient.shared

    let tools = ["nmap", "arp-scan", "dns", "nikto", "nuclei", "whatweb", "whois", "openssl"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cyberBackground.ignoresSafeArea()
                Form {
                    Section("Target") {
                        Picker("Select Target", selection: $selectedTargetId) {
                            Text("-- Select --").tag("")
                            ForEach(targets.filter { $0.authorizationStatus == .authorized && !$0.isArchived }) { t in
                                Text("\(t.name) (\(t.address))").tag(t.id)
                            }
                        }
                    }
                    Section("Scan Profile") {
                        Picker("Profile", selection: $selectedProfileId) {
                            Text("Custom").tag("")
                            ForEach(profiles) { p in
                                Text(p.name).tag(p.id)
                            }
                        }
                        .onChange(of: selectedProfileId) { _, newId in
                            if let p = profiles.first(where: { $0.id == newId }) {
                                selectedTool = p.tool
                                customFlags = p.flags ?? ""
                            }
                        }
                    }
                    Section("Tool & Flags") {
                        Picker("Tool", selection: $selectedTool) {
                            ForEach(tools, id: \.self) { Text($0.uppercased()).tag($0) }
                        }
                        TextField("Flags (optional)", text: $customFlags)
                            .font(.system(size: 13, design: .monospaced))
                    }
                    if !error.isEmpty {
                        Section { Text(error).foregroundColor(.red) }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Launch Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Launch") { Task { await launch() } }
                        .disabled(selectedTargetId.isEmpty || isLoading)
                }
            }
        }
        .task {
            async let t: [Target] = (try? client.request(Endpoints.targets)) ?? []
            async let p: [ScanProfile] = (try? client.request(Endpoints.scanProfiles)) ?? []
            targets = await t
            profiles = await p
        }
    }

    private func launch() async {
        isLoading = true
        error = ""
        defer { isLoading = false }
        do {
            let req = CreateScanRequest(
                targetId: selectedTargetId,
                tool: selectedTool,
                flags: customFlags.isEmpty ? nil : customFlags,
                profileId: selectedProfileId.isEmpty ? nil : selectedProfileId
            )
            let _: ScanJob = try await client.request(Endpoints.createScan(req))
            onCreated()
            dismiss()
        } catch let e as APIError {
            error = e.errorDescription ?? "Failed to launch scan"
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Error View

struct ErrorView: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(.red.opacity(0.7))
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            Button("Retry", action: retry)
                .foregroundColor(.cyberGreen)
        }
        .padding(40)
    }
}
