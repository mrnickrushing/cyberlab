import SwiftUI

struct TargetsView: View {
    @EnvironmentObject var cacheManager: CacheManager
    @State private var targets: [Target] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var searchText = ""
    @State private var showAddTarget = false
    @State private var showArchived = false
    private let client = APIClient.shared

    var filtered: [Target] {
        targets.filter { t in
            (showArchived ? t.isArchived : !t.isArchived) &&
            (searchText.isEmpty || t.name.localizedCaseInsensitiveContains(searchText) ||
             t.address.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cyberBackground.ignoresSafeArea()
                Group {
                    if isLoading {
                        ProgressView().tint(.cyberGreen)
                    } else if let error {
                        ErrorView(message: error) { Task { await loadTargets() } }
                    } else if filtered.isEmpty {
                        EmptyStateCard(
                            icon: "target",
                            title: targets.isEmpty ? "No Targets Yet" : "No Results",
                            subtitle: targets.isEmpty
                                ? "Add your first target to start scanning"
                                : "Try adjusting your search",
                            action: targets.isEmpty ? { showAddTarget = true } : nil,
                            actionLabel: "Add Target"
                        )
                        .padding(16)
                    } else {
                        List {
                            ForEach(filtered) { target in
                                NavigationLink(destination: TargetDetailView(target: target)) {
                                    TargetRow(target: target)
                                }
                                .listRowBackground(Color.cyberSurface)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        Task { await deleteTarget(target) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    Button {
                                        Task { await archiveTarget(target) }
                                    } label: {
                                        Label(target.isArchived ? "Unarchive" : "Archive", systemImage: "archivebox")
                                    }
                                    .tint(.orange)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search targets")
            .navigationTitle("Targets")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        withAnimation { showArchived.toggle() }
                    } label: {
                        Label(showArchived ? "Active" : "Archived",
                              systemImage: showArchived ? "tray.full" : "archivebox")
                            .foregroundColor(.cyberGreen)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddTarget = true } label: {
                        Image(systemName: "plus.circle.fill").foregroundColor(.cyberGreen)
                    }
                }
            }
            .sheet(isPresented: $showAddTarget) {
                AddTargetView { Task { await refresh() } }
            }
            .refreshable { await refresh() }
        }
        .task { await loadTargets() }
    }

    /// Stale-while-revalidate: paint cached targets immediately, then fetch fresh.
    private func loadTargets() async {
        let cached = cacheManager.cachedTargets()
        if !cached.isEmpty {
            targets = cached
            isLoading = false
        } else {
            isLoading = true
        }
        error = nil
        do {
            let fresh: [Target] = try await client.request(Endpoints.targets)
            targets = fresh
            cacheManager.store(fresh)
        } catch {
            if targets.isEmpty {
                self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
            }
        }
        isLoading = false
    }

    /// Pull-to-refresh: drop the cache, then re-fetch.
    private func refresh() async {
        cacheManager.invalidateAll()
        await loadTargets()
    }

    private func deleteTarget(_ target: Target) async {
        do {
            try await client.requestVoid(Endpoints.deleteTarget(target.id))
            cacheManager.invalidate(targetId: target.id)
            await loadTargets()
        } catch {}
    }

    private func archiveTarget(_ target: Target) async {
        do {
            let _: Target = try await client.request(Endpoints.archiveTarget(target.id))
            cacheManager.invalidateAll()
            await loadTargets()
        } catch {}
    }
}

struct TargetRow: View {
    let target: Target
    var body: some View {
        HStack(spacing: 12) {
            // Risk ring gauge
            RiskRing(riskLevel: target.riskLevel, type: target.type)

            VStack(alignment: .leading, spacing: 4) {
                Text(target.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(target.address)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                StatusBadge(text: target.authorizationStatus.label, color: target.authorizationStatus.color)
                StatusBadge(text: target.riskLevel.label, color: target.riskLevel.color)
            }
        }
        .padding(.vertical, 4)
    }
}

// ─── Risk Ring ─────────────────────────────────────────────────────────────────────
// Animated gauge ring on target list rows for at-a-glance risk health.

struct RiskRing: View {
    let riskLevel: RiskLevel
    let type: TargetType
    @State private var animated = false

    var fillFraction: CGFloat {
        switch riskLevel {
        case .critical: return 0.95
        case .high:     return 0.75
        case .medium:   return 0.55
        case .low:      return 0.30
        case .info:     return 0.10
        }
    }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color.cyberBorder, lineWidth: 3)
                .frame(width: 42, height: 42)
            // Fill arc — animates in on appear
            Circle()
                .trim(from: 0, to: animated ? fillFraction : 0)
                .stroke(
                    riskLevel.color,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 42, height: 42)
                .rotationEffect(.degrees(-90))
                .neonGlow(riskLevel.color, radius: riskLevel == .critical ? 4 : 0)
            // Center icon
            Image(systemName: type.systemImage)
                .font(.system(size: 13))
                .foregroundColor(riskLevel.color)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.1)) {
                animated = true
            }
        }
        .onDisappear { animated = false }
    }
}
