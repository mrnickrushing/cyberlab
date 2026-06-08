import SwiftUI

struct ScanHistoryView: View {
    @StateObject private var cache = ScanHistoryCache.shared
    @State private var selectedScan: ScanJob?

    var body: some View {
        NavigationStack {
            Group {
                if cache.cachedScans.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 48))
                            .foregroundColor(.cyberGreen.opacity(0.4))
                        Text("No cached scans yet")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.gray)
                        Text("Completed scans are saved automatically")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                } else {
                    List(cache.cachedScans) { scan in
                        Button {
                            selectedScan = scan
                        } label: {
                            ScanHistoryRow(scan: scan)
                        }
                        .listRowBackground(Color(white: 0.07))
                    }
                    .listStyle(.plain)
                    .background(Color.black)
                }
            }
            .navigationTitle("Scan History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !cache.cachedScans.isEmpty {
                        Button("Clear") {
                            cache.clear()
                        }
                        .foregroundColor(.red)
                        .font(.system(.body, design: .monospaced))
                    }
                }
            }
        }
        .sheet(item: $selectedScan) { scan in
            ScanHistoryDetailView(scan: scan)
        }
    }
}

private struct ScanHistoryRow: View {
    let scan: ScanJob

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(scan.tool.uppercased())
                    .font(.system(.subheadline, design: .monospaced, weight: .bold))
                    .foregroundColor(.cyberGreen)
                if let addr = Optional(scan.targetId) {
                    Text(addr)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.gray)
                }
                Text(scan.createdAt.prefix(10))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.6))
            }
            Spacer()
            StatusBadge(status: scan.status)
        }
        .padding(.vertical, 4)
    }
}

private struct StatusBadge: View {
    let status: ScanStatus
    var body: some View {
        Text(status.rawValue.uppercased())
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(statusColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(statusColor.opacity(0.15))
            .clipShape(Capsule())
    }
    var statusColor: Color {
        switch status {
        case .completed: return .green
        case .running:   return .cyan
        case .failed:    return .red
        case .cancelled: return .orange
        case .pending:   return .gray
        }
    }
}

private struct ScanHistoryDetailView: View {
    let scan: ScanJob
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(formatScan(scan))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.cyberGreen)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.black)
            .navigationTitle(scan.tool.uppercased())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }.foregroundColor(.cyberGreen)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        UIPasteboard.general.string = formatScan(scan)
                    } label: {
                        Image(systemName: "doc.on.doc").foregroundColor(.cyberGreen)
                    }
                }
            }
        }
    }

    func formatScan(_ s: ScanJob) -> String {
        var lines = ["[SCAN RECORD]", ""]
        lines.append("ID:       \(s.id)")
        lines.append("Tool:     \(s.tool)")
        lines.append("Status:   \(s.status.rawValue)")
        lines.append("Target:   \(s.targetId)")
        if let flags = s.flags { lines.append("Flags:    \(flags)") }
        lines.append("Created:  \(s.createdAt)")
        if let started = s.startedAt { lines.append("Started:  \(started)") }
        if let completed = s.completedAt { lines.append("Done:     \(completed)") }
        if let err = s.errorMessage { lines.append(""); lines.append("Error:    \(err)") }
        return lines.joined(separator: "\n")
    }
}

// Allow ScanJob to be used as sheet item (it already has Identifiable via id: String)
extension ScanJob: Equatable {
    static func == (lhs: ScanJob, rhs: ScanJob) -> Bool { lhs.id == rhs.id }
}
