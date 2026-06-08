import SwiftUI
import WidgetKit

struct ScansView: View {
    @EnvironmentObject var cacheManager: CacheManager
    @State private var scans: [ScanJobWithTarget] = []
    @State private var completedScanIds: Set<String> = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var filterStatus: ScanStatus? = nil
    @State private var refreshTimer: Timer?
    private let client = APIClient.shared

    var filtered: [ScanJobWithTarget] {
        guard let s = filterStatus else { return scans }
        return scans.filter { $0.status == s }
    }

    var hasActiveScans: Bool {
        scans.contains { $0.status.isActive }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cyberBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    // Status filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(label: "All", isSelected: filterStatus == nil) {
                                filterStatus = nil
                            }
                            ForEach([ScanStatus.running, .pending, .completed, .failed, .cancelled], id: \.self) { s in
                                FilterChip(label: s.label, color: s.color, isSelected: filterStatus == s) {
                                    filterStatus = (filterStatus == s) ? nil : s
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .background(Color.cyberBackground)

                    if isLoading {
                        Spacer()
                        ProgressView().tint(.cyberGreen)
                        Spacer()
                    } else if let error {
                        ErrorView(message: error) { Task { await loadScans() } }
                    } else if filtered.isEmpty {
                        Spacer()
                        EmptyStateCard(
                            icon: "scanner",
                            title: scans.isEmpty ? "No Scans Yet" : "No Matching Scans",
                            subtitle: scans.isEmpty
                                ? "Launch a scan from a target to get started"
                                : "Try a different status filter"
                        )
                        .padding(16)
                        Spacer()
                    } else {
                        List {
                            ForEach(filtered) { scan in
                                NavigationLink(destination: ScanDetailView(scanId: scan.id)) {
                                    ScanRow(scan: scan) {
                                        Task { await cancelScan(scan) }
                                    }
                                }
                                .listRowBackground(Color.cyberSurface)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Scans")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if hasActiveScans {
                        HStack(spacing: 4) {
                            Circle().fill(Color.cyberGreen).frame(width: 6, height: 6)
                                .pulsingGlow(.cyberGreen)
                            Text("Live").font(.system(size: 11, design: .monospaced)).foregroundColor(.cyberGreen)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await loadScans() } } label: {
                        Image(systemName: "arrow.clockwise").foregroundColor(.cyberGreen)
                    }
                }
            }
            .refreshable { await refresh() }
            .onAppear { startAutoRefresh() }
            .onDisappear { stopAutoRefresh() }
        }
        .task { await loadScans() }
    }

    private func loadScans() async {
        if scans.isEmpty { isLoading = true }
        error = nil
        do {
            scans = try await client.request(Endpoints.scans())
            refreshWidgetsIfScanCompleted()
        } catch {
            if scans.isEmpty {
                self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
            }
        }
        isLoading = false
    }

    /// Reload widget timelines once when a scan first reaches `.completed`,
    /// so the home-screen risk score reflects fresh results.
    private func refreshWidgetsIfScanCompleted() {
        let nowCompleted = Set(scans.filter { $0.status == .completed }.map(\.id))
        let newlyCompleted = nowCompleted.subtracting(completedScanIds)
        completedScanIds = nowCompleted
        if !newlyCompleted.isEmpty {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Pull-to-refresh: clear per-target scan caches, then re-fetch the live list.
    private func refresh() async {
        cacheManager.invalidateAll()
        await loadScans()
    }

    private func cancelScan(_ scan: ScanJobWithTarget) async {
        try? await client.requestVoid(Endpoints.cancelScan(scan.id))
        cacheManager.invalidate(targetId: scan.targetId)
        await loadScans()
    }

    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { _ in
            if hasActiveScans { Task { await loadScans() } }
        }
    }

    private func stopAutoRefresh() { refreshTimer?.invalidate(); refreshTimer = nil }
}

struct ScanRow: View {
    let scan: ScanJobWithTarget
    let onCancel: () -> Void
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("[\(scan.tool.uppercased())]")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyberGreen)
                    if scan.status.isActive {
                        ProgressView().scaleEffect(0.6).tint(.cyberGreen)
                    }
                }
                Text(scan.targetName ?? scan.targetAddress ?? "Unknown Target")
                    .font(.system(size: 13, weight: .medium)).foregroundColor(.white)
                Text(scan.createdAt.formattedDate)
                    .font(.system(size: 11)).foregroundColor(.white.opacity(0.4))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                StatusBadge(text: scan.status.label, color: scan.status.color)
                if scan.status.isActive {
                    Button("Cancel") { onCancel() }
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct FilterChip: View {
    let label: String
    var color: Color = .cyberGreen
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(isSelected ? .black : .white.opacity(0.6))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color : Color.cyberSurface)
                .cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(isSelected ? color : Color.cyberBorder, lineWidth: 1))
        }
    }
}
