import SwiftUI
import Charts
import WidgetKit

struct DashboardView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var stats: DashboardStats?
    @State private var isLoading = true
    @State private var error: String?
    @State private var showNewScan = false
    @State private var criticalDismissed = false
    private let client = APIClient.shared

    var criticalCount: Int { (stats?.findingsBySeverity.critical ?? 0) + (stats?.findingsBySeverity.high ?? 0) }

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

                            // Critical findings banner
                            if criticalCount > 0 && !criticalDismissed {
                                CriticalFindingsBanner(count: criticalCount) {
                                    withAnimation { criticalDismissed = true }
                                }
                            }

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

                            // Activity Feed
                            if !stats.recentScans.isEmpty {
                                ActivityFeedCard(scans: stats.recentScans)
                            } else {
                                EmptyStateCard(
                                    icon: "clock.arrow.circlepath",
                                    title: "No Recent Activity",
                                    subtitle: "Launch a scan to see activity here"
                                )
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    // Icon in nav bar
                    HStack(spacing: 8) {
                        Image("AppIconImage")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .neonGlow(.cyberGreen, radius: 4)
                        Text("CyberLab")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            NotificationCenter.default.post(name: .showCommandPalette, object: nil)
                        } label: {
                            Image(systemName: "magnifyingglass").foregroundColor(.cyberGreen)
                        }
                        Button { Task { await loadData() } } label: {
                            Image(systemName: "arrow.clockwise").foregroundColor(.cyberGreen)
                        }
                        Button { showNewScan = true } label: {
                            Image(systemName: "plus.circle.fill").foregroundColor(.cyberGreen)
                        }
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
        criticalDismissed = false
        do {
            stats = try await client.request(Endpoints.dashboard)
            if let stats { writeWidgetSnapshot(stats) }
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }

    /// Mirror the dashboard summary into shared storage so the home-screen
    /// and lock-screen widgets can render without network access.
    private func writeWidgetSnapshot(_ stats: DashboardStats) {
        let sev = stats.findingsBySeverity
        let topFindings: [WidgetFinding] = stats.recentScans.prefix(3).map {
            WidgetFinding(title: $0.targetName ?? $0.targetAddress ?? $0.tool.uppercased(),
                          severity: severityForScan(stats: stats))
        }
        let snapshot = WidgetSnapshot(
            riskScore: stats.securityScore,
            criticalCount: sev.critical,
            highCount: sev.high,
            topFindings: topFindings,
            lastScanDate: stats.recentScans.first?.createdAt.isoDate,
            targetName: stats.recentScans.first?.targetName ?? "CyberLab"
        )
        WidgetDataBridge.shared.write(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Pick the most severe bucket present so widget finding dots reflect
    /// overall posture (the dashboard feed doesn't carry per-scan severity).
    private func severityForScan(stats: DashboardStats) -> String {
        let sev = stats.findingsBySeverity
        if sev.critical > 0 { return "critical" }
        if sev.high > 0 { return "high" }
        if sev.medium > 0 { return "medium" }
        if sev.low > 0 { return "low" }
        return "info"
    }
}

// ─── Critical Findings Banner ─────────────────────────────────────────────────

struct CriticalFindingsBanner: View {
    let count: Int
    let onDismiss: () -> Void
    @State private var glowing = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundColor(.severityCritical)
                .neonGlow(.severityCritical, radius: glowing ? 8 : 3)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        glowing = true
                    }
                }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(count) CRITICAL/HIGH \(count == 1 ? "FINDING" : "FINDINGS")")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundColor(.severityCritical)
                    .glitchEffect()
                Text("Immediate action required")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.65))
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color.severityCritical.opacity(0.18), Color.cyberSurface],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.severityCritical.opacity(0.5), lineWidth: 1))
        .hudFrame(color: .severityCritical.opacity(0.6), length: 10)
    }
}

// ─── Activity Feed ────────────────────────────────────────────────────────────

struct ActivityFeedCard: View {
    let scans: [ScanJobWithTarget]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Activity", systemImage: "clock.arrow.circlepath")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(scans.count) events")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
            }

            ForEach(scans) { scan in
                NavigationLink(destination: ScanDetailView(scanId: scan.id)) {
                    ActivityRow(scan: scan)
                }
                .buttonStyle(.plain)

                if scan.id != scans.last?.id {
                    Divider().background(Color.cyberBorder)
                }
            }
        }
        .cyberCard()
    }
}

struct ActivityRow: View {
    let scan: ScanJobWithTarget

    var eventIcon: String {
        switch scan.status {
        case .running:   return "bolt.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed:    return "xmark.circle.fill"
        case .cancelled: return "slash.circle.fill"
        case .pending:   return "clock.fill"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            // Timeline dot
            ZStack {
                Circle()
                    .fill(scan.status.color.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: eventIcon)
                    .font(.system(size: 13))
                    .foregroundColor(scan.status.color)
                    .neonGlow(scan.status.color, radius: scan.status.isActive ? 5 : 0)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("[\(scan.tool.uppercased())]")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyberGreen)
                    if scan.status.isActive {
                        ProgressView().scaleEffect(0.5).tint(.cyberGreen)
                    }
                }
                Text(scan.targetName ?? scan.targetAddress ?? "Unknown")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                StatusBadge(text: scan.status.label, color: scan.status.color)
                Text(scan.createdAt.formattedDate)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.35))
            }
        }
    }
}

// ─── Empty State Card ─────────────────────────────────────────────────────────

struct EmptyStateCard: View {
    let icon: String
    let title: String
    let subtitle: String
    var action: (() -> Void)? = nil
    var actionLabel: String = "Get Started"

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(.cyberGreen.opacity(0.35))
                .neonGlow(.cyberGreen, radius: 4)
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.3))
                .multilineTextAlignment(.center)
            if let action {
                Button(action: action) {
                    Text(actionLabel)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.cyberGreen)
                        .cornerRadius(8)
                        .neonGlow(.cyberGreen, radius: 5)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color.cyberSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyberBorder, lineWidth: 1))
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
    var statusColor: Color { health.apiReachable ? .cyberGreen : .red }
    var statusLabel: String { health.apiReachable ? "ONLINE" : "OFFLINE" }
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Lab Health")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                HStack(spacing: 6) {
                    Circle().fill(statusColor).frame(width: 8, height: 8)
                        .pulsingGlow(statusColor)
                    Text(statusLabel)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(statusColor)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(health.workerQueueDepth)")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(health.workerQueueDepth > 0 ? .orange : .cyberGreen)
                Text("QUEUED JOBS")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .cyberCard()
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
        HapticFeedback.scanLaunch()
        do {
            let req = CreateScanRequest(
                targetId: selectedTargetId,
                tool: selectedTool,
                flags: customFlags.isEmpty ? nil : customFlags,
                profileId: selectedProfileId.isEmpty ? nil : selectedProfileId
            )
            let _: ScanJob = try await client.request(Endpoints.createScan(req))
            HapticFeedback.success()
            SoundManager.shared.play(.scanStart)
            let targetName = targets.first { $0.id == selectedTargetId }?.name ?? "Target"
            LiveActivityManager.shared.startScanActivity(targetName: targetName)
            onCreated()
            dismiss()
        } catch let e as APIError {
            HapticFeedback.error()
            error = e.errorDescription ?? "Failed to launch scan"
        } catch {
            HapticFeedback.error()
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
