import SwiftUI

enum DiffStatus {
    case new, removed, changed, unchanged
}

struct HostDiff: Identifiable {
    let id: String
    let ipAddress: String
    let status: DiffStatus
    let currentHost: NetworkHost?
    let previousHost: NetworkHost?
}

struct NetworkDiffView: View {
    let currentHosts: [NetworkHost]
    let subnet: String
    let allMaps: [NetworkMap]

    @State private var selectedMapId: String = ""
    @State private var comparisonHosts: [NetworkHost] = []
    @State private var isLoading = false
    private let client = APIClient.shared

    var diff: [HostDiff] {
        guard !comparisonHosts.isEmpty else { return [] }
        var result: [HostDiff] = []
        let currentByIP = Dictionary(uniqueKeysWithValues: currentHosts.map { ($0.ipAddress, $0) })
        let prevByIP    = Dictionary(uniqueKeysWithValues: comparisonHosts.map { ($0.ipAddress, $0) })
        let allIPs = Set(currentByIP.keys).union(prevByIP.keys)
        for ip in allIPs.sorted() {
            let cur = currentByIP[ip]
            let prev = prevByIP[ip]
            let status: DiffStatus
            if cur != nil && prev == nil { status = .new }
            else if cur == nil && prev != nil { status = .removed }
            else if cur?.isTrusted != prev?.isTrusted || cur?.hostname != prev?.hostname { status = .changed }
            else { status = .unchanged }
            result.append(HostDiff(id: ip, ipAddress: ip, status: status, currentHost: cur, previousHost: prev))
        }
        return result.sorted { a, b in
            let order: [DiffStatus] = [.new, .removed, .changed, .unchanged]
            return (order.firstIndex(of: a.status) ?? 0) < (order.firstIndex(of: b.status) ?? 0)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if allMaps.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 36))
                        .foregroundColor(.cyberGreen.opacity(0.35))
                    Text("No other maps to compare")
                        .foregroundColor(.white.opacity(0.4))
                    Text("Run discovery on another map first")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.25))
                }
                Spacer()
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Text("Compare with:")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                        Spacer()
                        Picker("Map", selection: $selectedMapId) {
                            Text("Select map").tag("")
                            ForEach(allMaps) { map in
                                Text(map.name).tag(map.id)
                            }
                        }
                        .tint(.cyberGreen)
                        .onChange(of: selectedMapId) { _, newId in
                            Task { await loadComparison(mapId: newId) }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(Color.cyberSurface)

                    if selectedMapId.isEmpty {
                        Spacer()
                        Text("Select a map to compare")
                            .foregroundColor(.white.opacity(0.35))
                            .font(.system(size: 14))
                        Spacer()
                    } else if isLoading {
                        Spacer()
                        ProgressView().tint(.cyberGreen)
                        Spacer()
                    } else {
                        diffSummaryBar
                        diffList
                    }
                }
            }
        }
        .background(Color.cyberBackground)
    }

    private var diffSummaryBar: some View {
        HStack(spacing: 20) {
            diffChip(count: diff.filter { $0.status == .new }.count, label: "New", color: .cyberGreen)
            diffChip(count: diff.filter { $0.status == .removed }.count, label: "Gone", color: .red)
            diffChip(count: diff.filter { $0.status == .changed }.count, label: "Changed", color: .orange)
            diffChip(count: diff.filter { $0.status == .unchanged }.count, label: "Same", color: .white.opacity(0.3))
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.cyberSurface.opacity(0.5))
    }

    private func diffChip(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }

    private var diffList: some View {
        List {
            ForEach(diff.filter { $0.status != .unchanged }) { item in
                DiffRow(item: item)
                    .listRowBackground(Color.cyberSurface)
            }
            if !diff.filter({ $0.status == .unchanged }).isEmpty {
                Section(header: Text("UNCHANGED").foregroundColor(.white.opacity(0.3)).font(.system(size: 10, weight: .semibold))) {
                    ForEach(diff.filter { $0.status == .unchanged }) { item in
                        DiffRow(item: item)
                            .listRowBackground(Color.cyberSurface)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func loadComparison(mapId: String) async {
        guard !mapId.isEmpty else { comparisonHosts = []; return }
        isLoading = true
        do {
            comparisonHosts = try await client.request(Endpoints.networkHosts(mapId))
        } catch {
            comparisonHosts = []
        }
        isLoading = false
    }
}

struct DiffRow: View {
    let item: HostDiff

    var statusColor: Color {
        switch item.status {
        case .new: return .cyberGreen
        case .removed: return .red
        case .changed: return .orange
        case .unchanged: return .white.opacity(0.3)
        }
    }

    var statusIcon: String {
        switch item.status {
        case .new: return "plus.circle.fill"
        case .removed: return "minus.circle.fill"
        case .changed: return "arrow.triangle.2.circlepath.circle.fill"
        case .unchanged: return "circle.fill"
        }
    }

    var statusLabel: String {
        switch item.status {
        case .new: return "NEW"
        case .removed: return "GONE"
        case .changed: return "CHANGED"
        case .unchanged: return "SAME"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .font(.system(size: 16))
            VStack(alignment: .leading, spacing: 3) {
                Text(item.ipAddress)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                if let hostname = (item.currentHost ?? item.previousHost)?.hostname, !hostname.isEmpty {
                    Text(hostname)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                }
                if item.status == .changed {
                    let prev = item.previousHost?.isTrusted == true ? "trusted" : "untrusted"
                    let cur  = item.currentHost?.isTrusted == true  ? "trusted" : "untrusted"
                    if prev != cur {
                        Text("\(prev) → \(cur)")
                            .font(.system(size: 10))
                            .foregroundColor(.orange.opacity(0.8))
                    }
                }
            }
            Spacer()
            Text(statusLabel)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(statusColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(statusColor.opacity(0.15))
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
        .opacity(item.status == .unchanged ? 0.5 : 1.0)
    }
}
