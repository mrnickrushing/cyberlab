import SwiftUI

// ─── ScanDiffView ─────────────────────────────────────────────────────────────
// Launched from ScanDetailView when the user taps "Compare with…".
// Loads two ScanResult objects and computes a client-side diff, then also
// tries the server-side /scans/:id/diff/:compareId endpoint when available.

struct ScanDiffView: View {
    let scanA: ScanJob        // newer scan (baseline)
    let scanB: ScanJob        // older scan (compare target)

    @State private var diff: ScanDiff?
    @State private var isLoading = true
    @State private var error: String?
    @State private var expandedSection: DiffChangeKind? = .new
    private let client = APIClient.shared

    var body: some View {
        ZStack {
            Color.cyberBackground.ignoresSafeArea()
            ScanlineOverlay()

            if isLoading {
                VStack(spacing: 16) {
                    ProgressView().tint(.cyberGreen).scaleEffect(1.4)
                    Text("COMPUTING DIFF...")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyberGreen.opacity(0.7))
                        .glitchEffect()
                }
            } else if let error {
                ErrorView(message: error) { Task { await loadDiff() } }
            } else if let diff {
                ScrollView {
                    VStack(spacing: 16) {
                        diffHeader(diff)
                        if !diff.hasChanges {
                            noChangesCard
                        } else {
                            if !diff.newRows.isEmpty {
                                diffSection(kind: .new, rows: diff.newRows)
                            }
                            if !diff.goneRows.isEmpty {
                                diffSection(kind: .gone, rows: diff.goneRows)
                            }
                            if !diff.changedRows.isEmpty {
                                diffSection(kind: .changed, rows: diff.changedRows)
                            }
                            if !diff.sameRows.isEmpty {
                                diffSection(kind: .same, rows: diff.sameRows)
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Scan Diff")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadDiff() }
    }

    // ── Header ────────────────────────────────────────────────────────────────

    private func diffHeader(_ diff: ScanDiff) -> some View {
        VStack(spacing: 12) {
            // Tool badge
            HStack {
                Text("[\(diff.tool.uppercased())]")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyberGreen)
                    .neonGlow(.cyberGreen, radius: 4)
                Spacer()
            }

            // Scan A vs Scan B timeline bar
            HStack(spacing: 0) {
                scanStamp(label: "OLDER", scan: scanB, color: .cyberCyan)
                Rectangle().fill(Color.cyberBorder).frame(height: 1)
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.cyberGreen)
                    .padding(.horizontal, 4)
                Rectangle().fill(Color.cyberBorder).frame(height: 1)
                scanStamp(label: "NEWER", scan: scanA, color: .cyberGreen)
            }

            // Summary chips
            HStack(spacing: 8) {
                changeChip(count: diff.newRows.count,     kind: .new)
                changeChip(count: diff.goneRows.count,    kind: .gone)
                changeChip(count: diff.changedRows.count, kind: .changed)
                changeChip(count: diff.sameRows.count,    kind: .same)
            }
        }
        .cyberCard()
        .hudFrame(color: .cyberGreen.opacity(0.4))
    }

    private func scanStamp(label: String, scan: ScanJob, color: Color) -> some View {
        VStack(alignment: .center, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(color.opacity(0.7))
            Text(scan.createdAt.formattedDate)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private func changeChip(count: Int, kind: DiffChangeKind) -> some View {
        HStack(spacing: 4) {
            Circle().fill(kindColor(kind)).frame(width: 6, height: 6)
            Text("\(count) \(kind.label)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(kindColor(kind))
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(kindColor(kind).opacity(0.1))
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(kindColor(kind).opacity(0.3), lineWidth: 1))
    }

    // ── Section ───────────────────────────────────────────────────────────────

    private func diffSection(kind: DiffChangeKind, rows: [DiffRow]) -> some View {
        let isExpanded = expandedSection == kind
        return VStack(spacing: 0) {
            // Section header — tappable to collapse
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedSection = isExpanded ? nil : kind
                }
            } label: {
                HStack(spacing: 10) {
                    kindIcon(kind)
                    Text(kind.label)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(kindColor(kind))
                        .neonGlow(kindColor(kind), radius: kind == .new ? 4 : 0)
                    Text("(\(rows.count))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(kindColor(kind).opacity(0.08))
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(rows) { row in
                        DiffRowView(row: row)
                        if row.id != rows.last?.id {
                            Divider().background(Color.cyberBorder)
                        }
                    }
                }
            }
        }
        .background(Color.cyberSurface)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(kindColor(kind).opacity(isExpanded ? 0.4 : 0.15), lineWidth: 1)
        )
    }

    // ── No changes ────────────────────────────────────────────────────────────

    private var noChangesCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.cyberGreen)
                .neonGlow(.cyberGreen, radius: 8)
            Text("NO CHANGES DETECTED")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.cyberGreen)
            Text("Both scans produced identical results.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .cyberCard()
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private func kindColor(_ kind: DiffChangeKind) -> Color {
        switch kind {
        case .new:     return .cyberGreen
        case .gone:    return .severityCritical
        case .changed: return .severityMedium
        case .same:    return .white.opacity(0.3)
        }
    }

    private func kindIcon(_ kind: DiffChangeKind) -> some View {
        let (name, color): (String, Color) = {
            switch kind {
            case .new:     return ("plus.circle.fill",    .cyberGreen)
            case .gone:    return ("minus.circle.fill",   .severityCritical)
            case .changed: return ("arrow.triangle.2.circlepath", .severityMedium)
            case .same:    return ("equal.circle",        .white.opacity(0.3))
            }
        }()
        return Image(systemName: name)
            .font(.system(size: 14))
            .foregroundColor(color)
    }

    // ── Data loading ──────────────────────────────────────────────────────────

    private func loadDiff() async {
        isLoading = true
        error = nil

        // Try server-side diff first
        if let serverDiff: ScanDiff = try? await client.request(
            Endpoints.scanDiff(scanA.id, compareId: scanB.id)) {
            diff = serverDiff
            isLoading = false
            return
        }

        // Fallback: client-side diff from raw scan results
        async let resA: ScanResult? = try? client.request(Endpoints.scanResults(scanA.id))
        async let resB: ScanResult? = try? client.request(Endpoints.scanResults(scanB.id))
        let (resultA, resultB) = await (resA, resB)

        diff = clientSideDiff(
            tool: scanA.tool,
            parsedA: resultA?.parsedData,
            parsedB: resultB?.parsedData
        )
        isLoading = false
    }

    // ── Client-side diff engine ───────────────────────────────────────────────

    private func clientSideDiff(tool: String, parsedA: ParsedData?, parsedB: ParsedData?) -> ScanDiff {
        var rows: [DiffRow] = []

        switch tool.lowercased() {

        case "nmap", "arp-scan":
            // Diff open ports across hosts
            let hostsA = dict(parsedA?.hosts ?? [], key: { "\($0.address ?? "?")" })
            let hostsB = dict(parsedB?.hosts ?? [], key: { "\($0.address ?? "?")" })
            let allHosts = Set(hostsA.keys).union(hostsB.keys)
            for host in allHosts.sorted() {
                let ha = hostsA[host]; let hb = hostsB[host]
                let portsA = portSet(ha?.ports)
                let portsB = portSet(hb?.ports)
                for port in portsA.union(portsB).sorted() {
                    let inA = portsA.contains(port); let inB = portsB.contains(port)
                    let kind: DiffChangeKind = inA && !inB ? .new : (!inA && inB ? .gone : .same)
                    rows.append(DiffRow(id: "\(host):port:\(port)", kind: kind,
                                       label: "\(host)  port \(port)",
                                       before: inB ? "open" : nil,
                                       after: inA ? "open" : nil))
                }
            }

        case "whatweb":
            let techA = techDict(parsedA?.technologies)
            let techB = techDict(parsedB?.technologies)
            let all = Set(techA.keys).union(techB.keys)
            for name in all.sorted() {
                let va = techA[name]; let vb = techB[name]
                let kind: DiffChangeKind
                if va != nil && vb == nil { kind = .new }
                else if va == nil && vb != nil { kind = .gone }
                else if va != vb { kind = .changed }
                else { kind = .same }
                rows.append(DiffRow(id: "tech:\(name)", kind: kind, label: name,
                                    before: vb, after: va))
            }

        case "nuclei", "nikto", "testssl":
            let fA = findingSet(parsedA?.findings)
            let fB = findingSet(parsedB?.findings)
            for f in fA.union(fB).sorted() {
                let inA = fA.contains(f); let inB = fB.contains(f)
                let kind: DiffChangeKind = inA && !inB ? .new : (!inA && inB ? .gone : .same)
                rows.append(DiffRow(id: "finding:\(f)", kind: kind, label: f,
                                    before: inB ? "found" : nil,
                                    after: inA ? "found" : nil))
            }

        case "dns":
            let rA = Set(parsedA?.records ?? [])
            let rB = Set(parsedB?.records ?? [])
            for r in rA.union(rB).sorted() {
                let kind: DiffChangeKind = rA.contains(r) && !rB.contains(r) ? .new
                    : (!rA.contains(r) && rB.contains(r) ? .gone : .same)
                rows.append(DiffRow(id: "record:\(r)", kind: kind, label: r,
                                    before: rB.contains(r) ? r : nil,
                                    after: rA.contains(r) ? r : nil))
            }

        case "amass", "subfinder":
            let sA = Set(parsedA?.subdomains ?? [])
            let sB = Set(parsedB?.subdomains ?? [])
            for s in sA.union(sB).sorted() {
                let kind: DiffChangeKind = sA.contains(s) && !sB.contains(s) ? .new
                    : (!sA.contains(s) && sB.contains(s) ? .gone : .same)
                rows.append(DiffRow(id: "sub:\(s)", kind: kind, label: s,
                                    before: sB.contains(s) ? s : nil,
                                    after: sA.contains(s) ? s : nil))
            }

        default:
            // Generic: compare raw field strings
            let fieldsA = genericFields(parsedA)
            let fieldsB = genericFields(parsedB)
            let keys = Set(fieldsA.keys).union(fieldsB.keys)
            for k in keys.sorted() {
                let va = fieldsA[k]; let vb = fieldsB[k]
                let kind: DiffChangeKind
                if va != nil && vb == nil { kind = .new }
                else if va == nil && vb != nil { kind = .gone }
                else if va != vb { kind = .changed }
                else { kind = .same }
                rows.append(DiffRow(id: "field:\(k)", kind: kind, label: k,
                                    before: vb, after: va))
            }
        }

        // Sort: NEW → GONE → CHANGED → SAME
        let order: [DiffChangeKind] = [.new, .gone, .changed, .same]
        rows.sort { order.firstIndex(of: $0.kind)! < order.firstIndex(of: $1.kind)! }

        return ScanDiff(scanId: scanA.id, compareId: scanB.id, tool: tool, rows: rows)
    }

    // ── Diff helpers ──────────────────────────────────────────────────────────

    private func dict<T>(_ arr: [T], key: (T) -> String) -> [String: T] {
        Dictionary(uniqueKeysWithValues: arr.map { (key($0), $0) })
    }

    private func portSet(_ ports: [NmapPort]?) -> Set<String> {
        Set((ports ?? []).map { "\($0.port)/\($0.protocol ?? "tcp")" })
    }

    private func techDict(_ techs: [WebTechnology]?) -> [String: String] {
        Dictionary(uniqueKeysWithValues: (techs ?? []).map { ($0.name, $0.version ?? "") })
    }

    private func findingSet(_ findings: [WebFinding]?) -> Set<String> {
        Set((findings ?? []).map { $0.displayTitle })
    }

    private func genericFields(_ p: ParsedData?) -> [String: String] {
        guard let p else { return [:] }
        var d: [String: String] = [:]
        if let v = p.ip       { d["IP"] = v }
        if let v = p.os       { d["OS"] = v }
        if let v = p.org      { d["Org"] = v }
        if let v = p.country  { d["Country"] = v }
        if let v = p.registrar { d["Registrar"] = v }
        if let ports = p.ports { d["Open Ports"] = ports.map(String.init).joined(separator: ", ") }
        return d
    }
}

// ─── DiffRowView ──────────────────────────────────────────────────────────────

struct DiffRowView: View {
    let row: DiffRow

    var kindColor: Color {
        switch row.kind {
        case .new:     return .cyberGreen
        case .gone:    return .severityCritical
        case .changed: return .severityMedium
        case .same:    return .white.opacity(0.25)
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // Left accent bar
            Rectangle()
                .fill(kindColor)
                .frame(width: 3)
                .cornerRadius(1.5)

            VStack(alignment: .leading, spacing: 4) {
                Text(row.label)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(row.kind == .same ? .white.opacity(0.45) : .white)
                    .lineLimit(2)

                // Before / after values for CHANGED rows
                if row.kind == .changed, let before = row.before, let after = row.after {
                    HStack(spacing: 8) {
                        Label(before, systemImage: "arrow.down.left")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.severityCritical.opacity(0.85))
                            .lineLimit(1)
                        Label(after, systemImage: "arrow.up.right")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.cyberGreen.opacity(0.85))
                            .lineLimit(1)
                    }
                } else if row.kind == .new, let after = row.after {
                    Text("+ \(after)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.cyberGreen.opacity(0.7))
                } else if row.kind == .gone, let before = row.before {
                    Text("– \(before)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.severityCritical.opacity(0.7))
                }
            }

            Spacer()

            // Kind badge
            Text(row.kind.label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(kindColor)
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(kindColor.opacity(0.12))
                .cornerRadius(4)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(kindColor.opacity(0.35), lineWidth: 1))
                .neonGlow(kindColor, radius: row.kind == .new ? 3 : 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(kindColor.opacity(row.kind == .same ? 0 : 0.04))
    }
}

// ─── Compare scan picker ──────────────────────────────────────────────────────
// Shown as a sheet when the user taps "Compare with…" in ScanDetailView.

struct ScanComparePicker: View {
    let currentScan: ScanJob
    let allScans: [ScanJob]          // same target+tool, excluding currentScan
    @Binding var selectedScan: ScanJob?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cyberBackground.ignoresSafeArea()
                if allScans.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "square.split.2x1")
                            .font(.system(size: 40)).foregroundColor(.cyberGreen.opacity(0.3))
                        Text("No other completed scans\nwith the same tool to compare.")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                    }
                } else {
                    List(allScans) { scan in
                        Button {
                            selectedScan = scan
                            dismiss()
                        } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(scan.createdAt.formattedFullDate)
                                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                        .foregroundColor(.white)
                                    HStack(spacing: 6) {
                                        StatusBadge(text: scan.status.label, color: scan.status.color)
                                        if let flags = scan.flags, !flags.isEmpty {
                                            Text(flags)
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundColor(.white.opacity(0.4))
                                                .lineLimit(1)
                                        }
                                    }
                                }
                                Spacer()
                                Image(systemName: "arrow.left.arrow.right")
                                    .foregroundColor(.cyberGreen.opacity(0.6))
                            }
                        }
                        .listRowBackground(Color.cyberSurface)
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Compare With")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.cyberGreen)
                }
            }
        }
    }
}
