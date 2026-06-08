import SwiftUI

// MARK: - Result model

enum PaletteResultType: String {
    case target = "Targets"
    case finding = "Findings"
    case scan = "Scans"

    var icon: String {
        switch self {
        case .target:  return "target"
        case .finding: return "exclamationmark.triangle"
        case .scan:    return "scanner"
        }
    }
    var color: Color {
        switch self {
        case .target:  return .cyberGreen
        case .finding: return .severityHigh
        case .scan:    return .cyberCyan
        }
    }
}

struct PaletteResult: Identifiable, Hashable {
    let id: String
    let type: PaletteResultType
    let title: String
    let subtitle: String
}

// MARK: - Command palette overlay

/// A ⌘K-style fuzzy search overlay that jumps to any target, finding, or scan.
struct CommandPaletteView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var searchFocused: Bool

    @State private var query = ""
    @State private var debouncedQuery = ""
    @State private var targets: [Target] = []
    @State private var findings: [Finding] = []
    @State private var scans: [ScanJobWithTarget] = []
    @State private var isLoading = true
    @State private var selectedIndex = 0
    @State private var debounceTask: Task<Void, Never>?

    @State private var navTarget: Target?
    @State private var navFinding: Finding?
    @State private var navScanId: String?

    private let client = APIClient.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cyberBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    searchField
                    Divider().background(Color.cyberBorder)
                    if isLoading {
                        Spacer(); ProgressView().tint(.cyberGreen); Spacer()
                    } else {
                        resultsList
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.foregroundColor(.cyberGreen)
                }
            }
            .navigationDestination(item: $navTarget) { TargetDetailView(target: $0) }
            .navigationDestination(item: $navFinding) { FindingDetailView(finding: $0) }
            .navigationDestination(item: Binding(
                get: { navScanId.map { ScanIDBox(id: $0) } },
                set: { navScanId = $0?.id }
            )) { ScanDetailView(scanId: $0.id) }
        }
        .task { await loadAll() }
        .onAppear { searchFocused = true }
        .onChange(of: query) { _, newValue in
            debounceTask?.cancel()
            debounceTask = Task {
                try? await Task.sleep(nanoseconds: 200_000_000)
                if !Task.isCancelled {
                    await MainActor.run { debouncedQuery = newValue; selectedIndex = 0 }
                }
            }
        }
    }

    // ─── Search field ─────────────────────────────────────────────────────────

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(.cyberGreen)
            TextField("Search targets, findings, scans…", text: $query)
                .font(.system(size: 16, design: .monospaced))
                .foregroundColor(.white)
                .focused($searchFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.go)
                .onSubmit { confirmSelection() }
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.white.opacity(0.4))
                }
            }
        }
        .padding(16)
    }

    // ─── Results ───────────────────────────────────────────────────────────────

    private var resultsList: some View {
        ScrollViewReader { proxy in
            List {
                if allResults.isEmpty {
                    Text(debouncedQuery.isEmpty ? "Start typing to search" : "No matches")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.35))
                        .listRowBackground(Color.cyberBackground)
                } else {
                    ForEach(groupedTypes, id: \.self) { type in
                        Section {
                            ForEach(resultsFor(type)) { result in
                                paletteRow(result, selected: result.id == selectedResult?.id)
                                    .id(result.id)
                                    .listRowBackground(
                                        result.id == selectedResult?.id ? Color.cyberGreen.opacity(0.12) : Color.cyberSurface
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture { open(result) }
                            }
                        } header: {
                            Text(type.rawValue.uppercased())
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyberGreen)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .onChange(of: selectedIndex) { _, _ in
                if let sel = selectedResult { withAnimation { proxy.scrollTo(sel.id, anchor: .center) } }
            }
        }
    }

    private func paletteRow(_ result: PaletteResult, selected: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7).fill(result.type.color.opacity(0.15)).frame(width: 34, height: 34)
                Image(systemName: result.type.icon).font(.system(size: 15)).foregroundColor(result.type.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(.system(size: 14, weight: .medium)).foregroundColor(.white).lineLimit(1)
                Text(result.subtitle)
                    .font(.system(size: 11, design: .monospaced)).foregroundColor(.white.opacity(0.45)).lineLimit(1)
            }
            Spacer()
            if selected {
                Image(systemName: "return").font(.system(size: 12)).foregroundColor(.cyberGreen)
            }
        }
        .padding(.vertical, 4)
    }

    // ─── Search logic ────────────────────────────────────────────────────────

    private var groupedTypes: [PaletteResultType] {
        [.target, .finding, .scan].filter { !resultsFor($0).isEmpty }
    }

    private var allResults: [PaletteResult] {
        groupedTypes.flatMap { resultsFor($0) }
    }

    private var selectedResult: PaletteResult? {
        let all = allResults
        guard !all.isEmpty else { return nil }
        return all[min(max(0, selectedIndex), all.count - 1)]
    }

    private func resultsFor(_ type: PaletteResultType) -> [PaletteResult] {
        let q = debouncedQuery.trimmingCharacters(in: .whitespaces).lowercased()
        switch type {
        case .target:
            return targets
                .filter { q.isEmpty ? true : fuzzy(q, in: [$0.name, $0.address]) }
                .prefix(8)
                .map { PaletteResult(id: $0.id, type: .target, title: $0.name, subtitle: $0.address) }
        case .finding:
            return findings
                .filter { q.isEmpty ? true : fuzzy(q, in: [$0.title, $0.description ?? "", $0.cveId ?? ""]) }
                .prefix(8)
                .map { PaletteResult(id: $0.id, type: .finding, title: $0.title, subtitle: "\($0.severity.label) · \($0.cveId ?? $0.status.label)") }
        case .scan:
            return scans
                .filter { q.isEmpty ? true : fuzzy(q, in: [$0.tool, $0.id, $0.status.rawValue, $0.targetName ?? ""]) }
                .prefix(8)
                .map { PaletteResult(id: $0.id, type: .scan, title: "[\($0.tool.uppercased())] \($0.targetName ?? $0.targetAddress ?? "")", subtitle: "\($0.status.label) · \(String($0.id.prefix(8)))") }
        }
    }

    /// Lightweight subsequence fuzzy match against any of the candidate strings.
    private func fuzzy(_ query: String, in candidates: [String]) -> Bool {
        for c in candidates {
            let hay = c.lowercased()
            if hay.contains(query) { return true }
            var qi = query.startIndex
            for ch in hay where qi != query.endIndex && ch == query[qi] {
                qi = query.index(after: qi)
            }
            if qi == query.endIndex { return true }
        }
        return false
    }

    private func confirmSelection() {
        if let result = selectedResult { open(result) }
    }

    private func open(_ result: PaletteResult) {
        switch result.type {
        case .target:
            navTarget = targets.first { $0.id == result.id }
        case .finding:
            navFinding = findings.first { $0.id == result.id }
        case .scan:
            navScanId = result.id
        }
    }

    private func loadAll() async {
        async let t: [Target] = (try? client.request(Endpoints.targets)) ?? []
        async let f: [Finding] = (try? client.request(Endpoints.findings())) ?? []
        async let s: [ScanJobWithTarget] = (try? client.request(Endpoints.scans())) ?? []
        targets = await t; findings = await f; scans = await s
        isLoading = false
    }
}

private struct ScanIDBox: Identifiable, Hashable { let id: String }
