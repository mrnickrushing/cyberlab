import SwiftUI

private struct WebTool: Identifiable {
    let id: String
    let tool: String
    let label: String
    let icon: String
    let description: String
    let color: Color
}

private let webTools: [WebTool] = [
    WebTool(id: "whatweb",  tool: "whatweb",  label: "Tech Stack",  icon: "square.stack.3d.up.fill",             description: "Detect CMS, frameworks, server tech",  color: .blue),
    WebTool(id: "nikto",    tool: "nikto",    label: "Web Vulns",   icon: "ant.fill",                            description: "Common web vulnerabilities & misconfigs", color: .orange),
    WebTool(id: "nuclei",   tool: "nuclei",   label: "Nuclei Scan", icon: "bolt.fill",                           description: "Template-based vulnerability scanner",  color: Color(red: 0.9, green: 0.1, blue: 0.1)),
    WebTool(id: "testssl",  tool: "testssl",  label: "TLS Audit",   icon: "lock.trianglebadge.exclamationmark.fill", description: "TLS/SSL cipher suite & cert analysis",  color: .purple),
    WebTool(id: "openssl",  tool: "openssl",  label: "Cert Info",   icon: "lock.fill",                           description: "Certificate viewer & expiry check",     color: .cyan),
    WebTool(id: "gobuster", tool: "gobuster", label: "Dir Scan",    icon: "folder.fill",                         description: "Directory & file discovery (lab only)",  color: .yellow),
]

struct WebAssessmentView: View {
    let target: Target
    @State private var scansByTool: [String: ScanJob] = [:]
    @State private var resultsByTool: [String: ScanResult] = [:]
    @State private var isLoading = true
    @State private var pollTimer: Timer?
    @State private var expandedTool: String?
    private let client = APIClient.shared

    var body: some View {
        ZStack {
            Color.cyberBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    targetHeader
                    ForEach(webTools) { wt in
                        WebToolCard(
                            wt: wt,
                            scan: scansByTool[wt.tool],
                            result: resultsByTool[wt.tool],
                            isExpanded: expandedTool == wt.tool,
                            onLaunch: { Task { await launch(wt) } },
                            onToggle: {
                                withAnimation {
                                    expandedTool = (expandedTool == wt.tool) ? nil : wt.tool
                                }
                            }
                        )
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Web Assessment")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadRecent() }
        .onDisappear { pollTimer?.invalidate() }
    }

    private var targetHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "safari")
                .font(.system(size: 20))
                .foregroundColor(.cyberGreen)
            VStack(alignment: .leading, spacing: 2) {
                Text(target.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(target.address)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.cyberGreen.opacity(0.7))
            }
            Spacer()
            StatusBadge(text: target.authorizationStatus.label, color: target.authorizationStatus.color)
        }
        .padding()
        .background(Color.cyberSurface)
        .cornerRadius(10)
    }

    private func loadRecent() async {
        isLoading = true
        do {
            let scans: [ScanJobWithTarget] = try await client.request(Endpoints.scans(targetId: target.id))
            var byTool: [String: ScanJob] = [:]
            for s in scans {
                if webTools.map(\.tool).contains(s.tool) {
                    if byTool[s.tool] == nil {
                        byTool[s.tool] = ScanJob(id: s.id, userId: s.userId, targetId: s.targetId, tool: s.tool,
                            flags: s.flags, status: s.status, progress: s.progress, workerJobId: nil,
                            errorMessage: s.errorMessage, createdAt: s.createdAt,
                            startedAt: s.startedAt, completedAt: s.completedAt, updatedAt: s.updatedAt)
                    }
                }
            }
            scansByTool = byTool
            await loadResults()
            startPolling()
        } catch {}
        isLoading = false
    }

    private func loadResults() async {
        for (tool, scan) in scansByTool where scan.status == .completed {
            if resultsByTool[tool] == nil {
                if let r: ScanResult = try? await client.request(Endpoints.scanResults(scan.id)) {
                    resultsByTool[tool] = r
                }
            }
        }
    }

    private func launch(_ wt: WebTool) async {
        guard target.authorizationStatus == .authorized else { return }
        do {
            let req = CreateScanRequest(targetId: target.id, tool: wt.tool, flags: nil, profileId: nil)
            let job: ScanJob = try await client.request(Endpoints.createScan(req))
            scansByTool[wt.tool] = job
            resultsByTool[wt.tool] = nil
            expandedTool = wt.tool
        } catch {}
    }

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { _ in
            Task { @MainActor in
                var changed = false
                for (tool, scan) in self.scansByTool where scan.status.isActive {
                    if let updated: ScanJob = try? await self.client.request(Endpoints.scan(scan.id)) {
                        self.scansByTool[tool] = updated
                        if updated.status == .completed {
                            if let r: ScanResult = try? await self.client.request(Endpoints.scanResults(scan.id)) {
                                self.resultsByTool[tool] = r
                            }
                            changed = true
                        }
                    }
                }
                _ = changed
            }
        }
    }
}

struct WebToolCard: View {
    let wt: WebTool
    let scan: ScanJob?
    let result: ScanResult?
    let isExpanded: Bool
    let onLaunch: () -> Void
    let onToggle: () -> Void

    var statusColor: Color {
        guard let s = scan else { return .white.opacity(0.2) }
        return s.status.color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(wt.color.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: wt.icon)
                            .font(.system(size: 17))
                            .foregroundColor(wt.color)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(wt.label)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Text(wt.description)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.4))
                            .lineLimit(1)
                    }
                    Spacer()
                    if let scan {
                        if scan.status.isActive {
                            ProgressView().tint(wt.color).scaleEffect(0.8)
                        } else {
                            StatusBadge(text: scan.status.label, color: scan.status.color)
                        }
                    }
                    Button(action: onLaunch) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(wt.color)
                    }
                    .disabled(scan?.status.isActive == true)
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().background(Color.cyberBorder).padding(.horizontal)
                if let scan, scan.status.isActive {
                    VStack(spacing: 8) {
                        ProgressView(value: Double(scan.progress ?? 0), total: 100).tint(wt.color)
                        Text("Running \(wt.label)…")
                            .font(.system(size: 12)).foregroundColor(.white.opacity(0.5))
                    }
                    .padding(14)
                } else if let result, let parsed = result.parsedData {
                    VStack(alignment: .leading, spacing: 10) {
                        ToolResultCard(tool: wt.tool, parsed: parsed)
                    }
                    .padding(14)
                } else if scan?.status == .failed {
                    Label(scan?.errorMessage ?? "Scan failed", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.red).font(.system(size: 12)).padding(14)
                } else {
                    Text("Tap ▶ to run this scan against \(wt.description.lowercased())")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.35))
                        .padding(14)
                }
            }
        }
        .background(Color.cyberSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyberBorder, lineWidth: 1))
    }
}
