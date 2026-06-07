import SwiftUI

private struct OSINTTool: Identifiable {
    let id: String
    let tool: String
    let label: String
    let icon: String
    let description: String
    let color: Color
    let requiresKey: Bool
}

private let osintTools: [OSINTTool] = [
    OSINTTool(id: "whois",      tool: "whois",      label: "WHOIS",        icon: "doc.plaintext.fill",          description: "Domain registration & expiry info",      color: .cyan,    requiresKey: false),
    OSINTTool(id: "shodan",     tool: "shodan",     label: "Shodan",       icon: "magnifyingglass.circle.fill",  description: "Exposed services, CVEs, banners",        color: .blue,    requiresKey: true),
    OSINTTool(id: "virustotal", tool: "virustotal", label: "VirusTotal",   icon: "shield.lefthalf.filled",       description: "Malicious/suspicious engine detections", color: .orange,  requiresKey: true),
    OSINTTool(id: "abuseipdb",  tool: "abuseipdb",  label: "AbuseIPDB",   icon: "exclamationmark.shield.fill",  description: "IP abuse reports & TOR detection",       color: .red,     requiresKey: true),
    OSINTTool(id: "ipinfo",     tool: "ipinfo",     label: "IPinfo",       icon: "location.circle.fill",         description: "Geolocation, ASN, ISP, timezone",        color: .green,   requiresKey: false),
    OSINTTool(id: "hibp",       tool: "hibp",       label: "HIBP",         icon: "flame.fill",                   description: "Domain data breach history",             color: .purple,  requiresKey: true),
]

struct OSINTView: View {
    let target: Target
    @State private var scansByTool: [String: ScanJob] = [:]
    @State private var resultsByTool: [String: ScanResult] = [:]
    @State private var isLoading = true
    @State private var expandedTool: String?
    @State private var pollTimer: Timer?
    private let client = APIClient.shared

    var body: some View {
        ZStack {
            Color.cyberBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    targetHeader
                    ForEach(osintTools) { ot in
                        OSINTToolCard(
                            ot: ot,
                            scan: scansByTool[ot.tool],
                            result: resultsByTool[ot.tool],
                            isExpanded: expandedTool == ot.tool,
                            onLaunch: { Task { await launch(ot) } },
                            onToggle: {
                                withAnimation { expandedTool = (expandedTool == ot.tool) ? nil : ot.tool }
                            }
                        )
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("OSINT")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadRecent() }
        .onDisappear { pollTimer?.invalidate() }
    }

    private var targetHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "eye.circle.fill")
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
            StatusBadge(text: target.type.uppercased(), color: .cyan)
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
                let toolIds = osintTools.map(\.tool)
                if toolIds.contains(s.tool), byTool[s.tool] == nil {
                    byTool[s.tool] = ScanJob(id: s.id, userId: s.userId, targetId: s.targetId, tool: s.tool,
                        flags: s.flags, status: s.status, progress: s.progress, workerJobId: nil,
                        errorMessage: s.errorMessage, createdAt: s.createdAt,
                        startedAt: s.startedAt, completedAt: s.completedAt, updatedAt: s.updatedAt)
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

    private func launch(_ ot: OSINTTool) async {
        do {
            let req = CreateScanRequest(targetId: target.id, tool: ot.tool, flags: nil, profileId: nil)
            let job: ScanJob = try await client.request(Endpoints.createScan(req))
            scansByTool[ot.tool] = job
            resultsByTool[ot.tool] = nil
            expandedTool = ot.tool
        } catch {}
    }

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { _ in
            Task { @MainActor in
                for (tool, scan) in self.scansByTool where scan.status.isActive {
                    if let updated: ScanJob = try? await self.client.request(Endpoints.scan(scan.id)) {
                        self.scansByTool[tool] = updated
                        if updated.status == .completed {
                            if let r: ScanResult = try? await self.client.request(Endpoints.scanResults(scan.id)) {
                                self.resultsByTool[tool] = r
                            }
                        }
                    }
                }
            }
        }
    }
}

// ─── Per-tool card ────────────────────────────────────────────────────────────

struct OSINTToolCard: View {
    let ot: OSINTTool
    let scan: ScanJob?
    let result: ScanResult?
    let isExpanded: Bool
    let onLaunch: () -> Void
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8).fill(ot.color.opacity(0.15)).frame(width: 40, height: 40)
                        Image(systemName: ot.icon).font(.system(size: 17)).foregroundColor(ot.color)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(ot.label)
                                .font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                            if ot.requiresKey {
                                Image(systemName: "key.fill")
                                    .font(.system(size: 9)).foregroundColor(.white.opacity(0.3))
                            }
                        }
                        Text(ot.description)
                            .font(.system(size: 11)).foregroundColor(.white.opacity(0.4)).lineLimit(1)
                    }
                    Spacer()
                    if let scan {
                        if scan.status.isActive {
                            ProgressView().tint(ot.color).scaleEffect(0.8)
                        } else {
                            StatusBadge(text: scan.status.label, color: scan.status.color)
                        }
                    }
                    Button(action: onLaunch) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 24)).foregroundColor(ot.color)
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
                        ProgressView(value: Double(scan.progress ?? 0), total: 100).tint(ot.color)
                        Text("Running \(ot.label)…").font(.system(size: 12)).foregroundColor(.white.opacity(0.5))
                    }
                    .padding(14)
                } else if let result, let parsed = result.parsedData {
                    if let err = parsed.error {
                        Label(err, systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange).font(.system(size: 12)).padding(14)
                    } else {
                        OSINTResultCard(tool: ot.tool, parsed: parsed).padding(14)
                    }
                } else if scan?.status == .failed {
                    Label(scan?.errorMessage ?? "Scan failed", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.red).font(.system(size: 12)).padding(14)
                } else {
                    Text("Tap ▶ to run \(ot.label) against this target")
                        .font(.system(size: 12)).foregroundColor(.white.opacity(0.35)).padding(14)
                }
            }
        }
        .background(Color.cyberSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyberBorder, lineWidth: 1))
    }
}

// ─── Tool-specific result renderers ──────────────────────────────────────────

struct OSINTResultCard: View {
    let tool: String
    let parsed: ParsedData

    var body: some View {
        switch tool {
        case "whois":      WHOISResultView(parsed: parsed)
        case "shodan":     ShodanResultView(parsed: parsed)
        case "virustotal": VirusTotalResultView(parsed: parsed)
        case "abuseipdb":  AbuseIPDBResultView(parsed: parsed)
        case "ipinfo":     IPInfoResultView(parsed: parsed)
        case "hibp":       HIBPResultView(parsed: parsed)
        default:           EmptyView()
        }
    }
}

// WHOIS ────────────────────────────────────────────────────────────────────────

struct WHOISResultView: View {
    let parsed: ParsedData
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            osintKV("Registrar",     parsed.registrar)
            osintKV("Organization",  parsed.registrantOrganization)
            osintKV("Country",       parsed.registrantCountry)
            osintKV("Created",       parsed.creationDate)
            osintKV("Expires",       parsed.registryExpiryDate)
            osintKV("Name Server",   parsed.nameServer)
            if [parsed.registrar, parsed.registrantOrganization, parsed.registrantCountry, parsed.creationDate].allSatisfy({ $0 == nil }) {
                Text("No structured WHOIS data available — check raw output")
                    .font(.system(size: 11)).foregroundColor(.white.opacity(0.35))
            }
        }
    }
}

// Shodan ───────────────────────────────────────────────────────────────────────

struct ShodanResultView: View {
    let parsed: ParsedData
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            osintKV("IP",         parsed.ip)
            osintKV("Org",        parsed.org)
            osintKV("ISP",        parsed.isp)
            osintKV("ASN",        parsed.asn)
            osintKV("Country",    parsed.country)
            osintKV("City",       parsed.city)
            osintKV("OS",         parsed.os)
            osintKV("Updated",    parsed.lastUpdate)
            if let ports = parsed.ports, !ports.isEmpty {
                Divider().background(Color.cyberBorder)
                Text("Open Ports: " + ports.map { String($0) }.joined(separator: ", "))
                    .font(.system(size: 11, design: .monospaced)).foregroundColor(.cyberGreen)
            }
            if let vulns = parsed.vulns, !vulns.isEmpty {
                Divider().background(Color.cyberBorder)
                VStack(alignment: .leading, spacing: 3) {
                    Text("CVEs (\(vulns.count))")
                        .font(.system(size: 11, weight: .semibold)).foregroundColor(.red.opacity(0.8))
                    ForEach(vulns.prefix(10), id: \.self) { v in
                        Text(v).font(.system(size: 10, design: .monospaced)).foregroundColor(.orange)
                    }
                    if vulns.count > 10 { Text("+ \(vulns.count - 10) more").font(.system(size: 10)).foregroundColor(.white.opacity(0.3)) }
                }
            }
        }
    }
}

// VirusTotal ───────────────────────────────────────────────────────────────────

struct VirusTotalResultView: View {
    let parsed: ParsedData
    var totalEngines: Int { (parsed.malicious ?? 0) + (parsed.suspicious ?? 0) + (parsed.harmless ?? 0) + (parsed.undetected ?? 0) }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                vtStat("Malicious",  parsed.malicious ?? 0,  .red)
                vtStat("Suspicious", parsed.suspicious ?? 0, .orange)
                vtStat("Harmless",   parsed.harmless ?? 0,   .cyberGreen)
                vtStat("Undetected", parsed.undetected ?? 0, .gray)
            }
            if totalEngines > 0 {
                ProgressView(value: Double((parsed.malicious ?? 0) + (parsed.suspicious ?? 0)), total: Double(totalEngines))
                    .tint(.red)
                Text("\((parsed.malicious ?? 0) + (parsed.suspicious ?? 0)) of \(totalEngines) engines flagged")
                    .font(.system(size: 11)).foregroundColor(.white.opacity(0.4))
            }
            if let rep = parsed.reputation {
                osintKV("Reputation", "\(rep)")
            }
        }
    }

    private func vtStat(_ label: String, _ value: Int, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text("\(value)").font(.system(size: 18, weight: .bold)).foregroundColor(color)
            Text(label).font(.system(size: 9)).foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }
}

// AbuseIPDB ───────────────────────────────────────────────────────────────────

struct AbuseIPDBResultView: View {
    let parsed: ParsedData
    var scoreColor: Color {
        let s = parsed.abuseConfidenceScore ?? 0
        if s >= 75 { return .red }
        if s >= 25 { return .orange }
        return .cyberGreen
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("\(parsed.abuseConfidenceScore ?? 0)%")
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundColor(scoreColor)
                    Text("Confidence").font(.system(size: 10)).foregroundColor(.white.opacity(0.4))
                }
                VStack(alignment: .leading, spacing: 4) {
                    if parsed.isTor == true {
                        Label("TOR Exit Node", systemImage: "flame.fill").font(.system(size: 11)).foregroundColor(.red)
                    }
                    if parsed.isPublic == true {
                        Label("Public IP", systemImage: "globe").font(.system(size: 11)).foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            Divider().background(Color.cyberBorder)
            osintKV("Reports",      parsed.totalReports.map { "\($0)" })
            osintKV("Distinct Users", parsed.numDistinctUsers.map { "\($0)" })
            osintKV("Country",      parsed.countryCode)
            osintKV("ISP",          parsed.isp)
            osintKV("Usage Type",   parsed.usageType)
            osintKV("Last Report",  parsed.lastReportedAt)
        }
    }
}

// IPinfo ───────────────────────────────────────────────────────────────────────

struct IPInfoResultView: View {
    let parsed: ParsedData
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let loc = parsed.loc {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill").foregroundColor(.cyberGreen)
                    Text(loc).font(.system(size: 12, design: .monospaced)).foregroundColor(.cyberGreen)
                    Text("\(parsed.city ?? ""), \(parsed.region ?? ""), \(parsed.country ?? "")")
                        .font(.system(size: 12)).foregroundColor(.white.opacity(0.6))
                }
            }
            Divider().background(Color.cyberBorder)
            osintKV("IP",       parsed.ip)
            osintKV("Hostname", parsed.hostname)
            osintKV("Org/ASN",  parsed.org)
            osintKV("Timezone", parsed.timezone)
            osintKV("Postal",   parsed.postal)
        }
    }
}

// HIBP ─────────────────────────────────────────────────────────────────────────

struct HIBPResultView: View {
    let parsed: ParsedData
    var count: Int { parsed.breachCount ?? parsed.breaches?.count ?? 0 }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: count > 0 ? "flame.fill" : "checkmark.shield.fill")
                    .font(.system(size: 28))
                    .foregroundColor(count > 0 ? .red : .cyberGreen)
                VStack(alignment: .leading, spacing: 2) {
                    Text(count > 0 ? "\(count) breach(es) found" : "No breaches found")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(count > 0 ? .red : .cyberGreen)
                    if let domain = parsed.domain {
                        Text(domain).font(.system(size: 11)).foregroundColor(.white.opacity(0.4))
                    }
                }
            }
            if let breaches = parsed.breaches, !breaches.isEmpty {
                Divider().background(Color.cyberBorder)
                Text("Breach Names")
                    .font(.system(size: 11, weight: .semibold)).foregroundColor(.white.opacity(0.5))
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(breaches.prefix(20), id: \.self) { b in
                        Text(b)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Color.cyberBackground)
                            .cornerRadius(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if breaches.count > 20 {
                    Text("+ \(breaches.count - 20) more breaches")
                        .font(.system(size: 10)).foregroundColor(.white.opacity(0.3))
                }
            }
        }
    }
}

// ─── Shared helper ────────────────────────────────────────────────────────────

@ViewBuilder
private func osintKV(_ label: String, _ value: String?) -> some View {
    if let value, !value.isEmpty {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 88, alignment: .leading)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
                .textSelection(.enabled)
        }
    }
}
