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
                        ScanJobCard(scan: scan)
                        if let parsed = result?.parsedData {
                            ToolResultCard(tool: scan.tool, parsed: parsed)
                        }
                        if let raw = result?.rawOutput, !raw.isEmpty {
                            RawOutputCard(raw: raw, isExpanded: $showRaw)
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
            if self.scan?.status.isActive == true { Task { await self.loadData() } }
        }
    }
    private func stopPolling() { refreshTimer?.invalidate(); refreshTimer = nil }
}

// ─── Job header card ──────────────────────────────────────────────────────────

struct ScanJobCard: View {
    let scan: ScanJob
    var body: some View {
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
                Text("Progress: \(scan.progress ?? 0)%")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
            Divider().background(Color.cyberBorder)
            InfoRow(label: "Started",   value: scan.startedAt?.formattedFullDate ?? "Pending")
            if let c = scan.completedAt { InfoRow(label: "Completed", value: c.formattedFullDate) }
            if let f = scan.flags, !f.isEmpty { InfoRow(label: "Flags", value: f) }
            if let e = scan.errorMessage {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red).font(.caption)
                    Text(e).font(.system(size: 12)).foregroundColor(.red.opacity(0.8))
                }
            }
        }
        .cyberCard()
    }
}

// ─── Tool-specific result dispatcher ──────────────────────────────────────────

struct ToolResultCard: View {
    let tool: String
    let parsed: ParsedData

    var body: some View {
        switch tool {
        case "nmap", "masscan":
            if let hosts = parsed.hosts, !hosts.isEmpty {
                NmapResultCard(hosts: hosts)
            }
        case "whatweb":
            WhatWebResultCard(parsed: parsed)
        case "nikto":
            WebFindingsCard(title: "Nikto Vulnerabilities", icon: "ant.fill", parsed: parsed)
        case "nuclei":
            WebFindingsCard(title: "Nuclei Findings", icon: "bolt.fill", parsed: parsed)
        case "testssl":
            WebFindingsCard(title: "TLS Issues", icon: "lock.trianglebadge.exclamationmark.fill", parsed: parsed)
        case "openssl":
            TLSCertCard(parsed: parsed)
        case "gobuster":
            GobusterResultCard(parsed: parsed)
        case "dns":
            DNSResultCard(parsed: parsed)
        case "amass", "subfinder":
            SubdomainResultCard(parsed: parsed)
        case "arp-scan":
            ArpScanResultCard(parsed: parsed)
        default:
            EmptyView()
        }
    }
}

// ─── Nmap ─────────────────────────────────────────────────────────────────────

struct NmapResultCard: View {
    let hosts: [NmapHost]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("\(hosts.count) host(s) discovered", systemImage: "network")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
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
                    if let h = host.hostname { Text(h).font(.system(size: 11)).foregroundColor(.white.opacity(0.5)) }
                    if let os = host.os { Label(os, systemImage: "desktopcomputer").font(.system(size: 11)).foregroundColor(.white.opacity(0.4)) }
                    if let ports = host.ports, !ports.isEmpty {
                        Divider().background(Color.cyberBorder)
                        ForEach(ports, id: \.port) { port in
                            HStack {
                                Text("\(port.port)/\(port.protocol ?? "tcp")")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(port.state == "open" ? .cyberGreen : .gray)
                                    .frame(width: 80, alignment: .leading)
                                Text(port.service ?? "").font(.system(size: 12)).foregroundColor(.white.opacity(0.7))
                                Spacer()
                                if let p = port.product { Text(p).font(.system(size: 10)).foregroundColor(.white.opacity(0.4)) }
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

// ─── WhatWeb ──────────────────────────────────────────────────────────────────

struct WhatWebResultCard: View {
    let parsed: ParsedData
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Technology Stack", systemImage: "square.stack.3d.up.fill")
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.white.opacity(0.7))
                Spacer()
                if let status = parsed.httpStatus {
                    StatusBadge(
                        text: "HTTP \(status)",
                        color: status < 300 ? .cyberGreen : status < 400 ? .orange : .red
                    )
                }
            }
            if let target = parsed.target {
                Text(target)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.cyberGreen.opacity(0.7))
            }
            if let techs = parsed.technologies, !techs.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(Array(techs.enumerated()), id: \.offset) { _, tech in
                        TechChip(tech: tech)
                    }
                }
            } else {
                Text("No technologies detected").foregroundColor(.white.opacity(0.3)).font(.system(size: 13))
            }
        }
        .cyberCard()
    }
}

struct TechChip: View {
    let tech: WebTechnology
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(tech.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
            if let version = tech.version {
                Text("v\(version)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.cyberGreen)
            }
            if let detail = tech.detail, tech.version == nil {
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cyberBackground)
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.cyberBorder, lineWidth: 1))
    }
}

// ─── Nikto / Nuclei / testssl findings ────────────────────────────────────────

struct WebFindingsCard: View {
    let title: String
    let icon: String
    let parsed: ParsedData
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.white.opacity(0.7))
                Spacer()
                if let count = parsed.count ?? parsed.findings?.count {
                    Text("\(count)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.cyberGreen)
                }
            }
            if let findings = parsed.findings, !findings.isEmpty {
                ForEach(Array(findings.enumerated()), id: \.offset) { _, f in
                    WebFindingRow(finding: f)
                }
            } else {
                Label("No issues found", systemImage: "checkmark.seal.fill")
                    .foregroundColor(.cyberGreen.opacity(0.7))
                    .font(.system(size: 13))
            }
        }
        .cyberCard()
    }
}

struct WebFindingRow: View {
    let finding: WebFinding
    @State private var expanded = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button { withAnimation { expanded.toggle() } } label: {
                HStack(alignment: .top, spacing: 8) {
                    SeverityBadge(severity: finding.severityEnum)
                    Text(finding.displayTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.white.opacity(0.3))
                        .font(.system(size: 11))
                }
            }
            if expanded {
                if !finding.displayDescription.isEmpty {
                    Text(finding.displayDescription)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                        .textSelection(.enabled)
                }
                if let matchedAt = finding.matchedAt {
                    Label(matchedAt, systemImage: "link")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.cyberGreen.opacity(0.7))
                }
                if let tags = finding.tags, !tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(tags.prefix(4), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Color.cyberBorder)
                                .cornerRadius(3)
                        }
                    }
                }
            }
        }
        .padding(8)
        .background(Color.cyberBackground)
        .cornerRadius(6)
    }
}

// ─── TLS / OpenSSL cert ───────────────────────────────────────────────────────

struct TLSCertCard: View {
    let parsed: ParsedData
    var isValid: Bool { parsed.valid ?? false }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("TLS Certificate", systemImage: isValid ? "lock.fill" : "lock.open.fill")
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.white.opacity(0.7))
                Spacer()
                StatusBadge(text: isValid ? "Valid" : "Invalid", color: isValid ? .cyberGreen : .red)
            }
            Divider().background(Color.cyberBorder)
            if let subject = parsed.subject   { InfoRow(label: "Subject",   value: subject) }
            if let issuer  = parsed.issuer    { InfoRow(label: "Issuer",    value: issuer) }
            if let nb      = parsed.notBefore { InfoRow(label: "Not Before", value: nb) }
            if let na      = parsed.notAfter  { InfoRow(label: "Not After",  value: na) }
            if let proto   = parsed.protocol  { InfoRow(label: "Protocol",   value: proto) }
            if let cipher  = parsed.cipher    { InfoRow(label: "Cipher",     value: cipher) }
            if let vm      = parsed.verifyMessage {
                HStack(alignment: .top) {
                    Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isValid ? .cyberGreen : .red)
                    Text(vm).font(.system(size: 12)).foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .cyberCard()
    }
}

// ─── Gobuster directories ─────────────────────────────────────────────────────

struct GobusterResultCard: View {
    let parsed: ParsedData
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Directories Found", systemImage: "folder.fill")
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.white.opacity(0.7))
                Spacer()
                Text("\(parsed.found?.count ?? 0)")
                    .font(.system(size: 12, weight: .bold)).foregroundColor(.cyberGreen)
            }
            if let found = parsed.found, !found.isEmpty {
                ForEach(Array(found.enumerated()), id: \.offset) { _, entry in
                    HStack {
                        Text(entry.path)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white)
                        Spacer()
                        StatusBadge(
                            text: "\(entry.status)",
                            color: entry.status < 300 ? .cyberGreen : entry.status < 400 ? .orange : .red
                        )
                    }
                    .padding(.vertical, 2)
                }
            } else {
                Text("No directories discovered").foregroundColor(.white.opacity(0.3)).font(.system(size: 13))
            }
        }
        .cyberCard()
    }
}

// ─── DNS records ──────────────────────────────────────────────────────────────

struct DNSResultCard: View {
    let parsed: ParsedData
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("DNS \(parsed.type ?? "Records")", systemImage: "globe")
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.white.opacity(0.7))
                Spacer()
                Text("\(parsed.records?.count ?? 0) record(s)")
                    .font(.system(size: 11)).foregroundColor(.white.opacity(0.4))
            }
            if let records = parsed.records, !records.isEmpty {
                ForEach(records, id: \.self) { record in
                    Text(record)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.cyberGreen.opacity(0.9))
                        .textSelection(.enabled)
                }
            } else {
                Text("No records returned").foregroundColor(.white.opacity(0.3)).font(.system(size: 13))
            }
        }
        .cyberCard()
    }
}

// ─── Subdomains (amass / subfinder) ──────────────────────────────────────────

struct SubdomainResultCard: View {
    let parsed: ParsedData
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Subdomains", systemImage: "list.bullet.indent")
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.white.opacity(0.7))
                Spacer()
                Text("\(parsed.subdomains?.count ?? parsed.count ?? 0) found")
                    .font(.system(size: 11)).foregroundColor(.cyberGreen)
            }
            if let subs = parsed.subdomains, !subs.isEmpty {
                ForEach(subs.prefix(50), id: \.self) { sub in
                    Text(sub)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                        .textSelection(.enabled)
                }
                if subs.count > 50 {
                    Text("+ \(subs.count - 50) more…")
                        .font(.system(size: 11)).foregroundColor(.white.opacity(0.35))
                }
            } else {
                Text("No subdomains found").foregroundColor(.white.opacity(0.3)).font(.system(size: 13))
            }
        }
        .cyberCard()
    }
}

// ─── ARP scan hosts ───────────────────────────────────────────────────────────

struct ArpScanResultCard: View {
    let parsed: ParsedData
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Live Hosts", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.white.opacity(0.7))
                Spacer()
                Text("\(parsed.hosts?.count ?? parsed.count ?? 0) hosts")
                    .font(.system(size: 11)).foregroundColor(.cyberGreen)
            }
            if let hosts = parsed.hosts, !hosts.isEmpty {
                ForEach(Array(hosts.enumerated()), id: \.offset) { _, host in
                    HStack(spacing: 10) {
                        Text(host.address ?? "")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(.cyberGreen)
                        if let h = host.hostname { Text(h).font(.system(size: 11)).foregroundColor(.white.opacity(0.5)) }
                    }
                }
            }
        }
        .cyberCard()
    }
}

// ─── Raw output ───────────────────────────────────────────────────────────────

struct RawOutputCard: View {
    let raw: String
    @Binding var isExpanded: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { withAnimation { isExpanded.toggle() } } label: {
                HStack {
                    Text("Raw Output")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            if isExpanded {
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
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

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
