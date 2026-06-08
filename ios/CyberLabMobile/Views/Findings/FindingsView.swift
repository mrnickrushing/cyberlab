import SwiftUI

struct FindingsView: View {
    @EnvironmentObject var cacheManager: CacheManager
    @State private var findings: [Finding] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var filterSeverity: FindingSeverity? = nil
    @State private var filterStatus: FindingStatus? = nil
    private let client = APIClient.shared

    var filtered: [Finding] {
        findings.filter { f in
            (filterSeverity == nil || f.severity == filterSeverity) &&
            (filterStatus == nil || f.status == filterStatus)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cyberBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    // Severity filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(label: "All", isSelected: filterSeverity == nil) {
                                filterSeverity = nil
                            }
                            ForEach(FindingSeverity.allCases, id: \.self) { s in
                                FilterChip(label: s.label, color: s.color, isSelected: filterSeverity == s) {
                                    filterSeverity = (filterSeverity == s) ? nil : s
                                }
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 8)
                    }

                    if isLoading {
                        Spacer(); ProgressView().tint(.cyberGreen); Spacer()
                    } else if let error {
                        ErrorView(message: error) { Task { await loadFindings() } }
                    } else if filtered.isEmpty {
                        VStack {
                            Spacer()
                            EmptyStateCard(
                                icon: "checkmark.shield",
                                title: findings.isEmpty ? "No Findings" : "No Matches",
                                subtitle: findings.isEmpty
                                    ? "Run scans to discover vulnerabilities"
                                    : "Try clearing your filters"
                            )
                            .padding(16)
                            Spacer()
                        }
                    } else {
                        List {
                            ForEach(filtered) { finding in
                                NavigationLink(destination: FindingDetailView(finding: finding)) {
                                    FindingRow(finding: finding)
                                }
                                .listRowBackground(Color.cyberSurface)
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        HapticFeedback.statusChange()
                                        Task { await updateFindingStatus(finding, status: .fixed) }
                                    } label: {
                                        Label("Mark Fixed", systemImage: "checkmark.circle.fill")
                                    }
                                    .tint(.cyberGreen)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        HapticFeedback.statusChange()
                                        Task { await updateFindingStatus(finding, status: .acceptedRisk) }
                                    } label: {
                                        Label("Accept Risk", systemImage: "hand.raised.fill")
                                    }
                                    .tint(.orange)
                                    Button {
                                        HapticFeedback.statusChange()
                                        Task { await updateFindingStatus(finding, status: .falsePositive) }
                                    } label: {
                                        Label("False Positive", systemImage: "xmark.circle")
                                    }
                                    .tint(.gray)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Findings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await loadFindings() } } label: {
                        Image(systemName: "arrow.clockwise").foregroundColor(.cyberGreen)
                    }
                }
            }
            .refreshable { await refresh() }
        }
        .task { await loadFindings() }
    }

    /// Stale-while-revalidate: paint cached findings immediately, then fetch fresh.
    private func loadFindings() async {
        let cached = cacheManager.cachedFindings()
        if !cached.isEmpty {
            findings = cached
            isLoading = false
        } else {
            isLoading = true
        }
        error = nil
        do {
            let fresh: [Finding] = try await client.request(Endpoints.findings())
            findings = fresh
            cacheManager.store(fresh)
        } catch {
            if findings.isEmpty {
                self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
                HapticFeedback.error()
            }
        }
        isLoading = false
    }

    private func refresh() async {
        cacheManager.store([Finding]())
        await loadFindings()
    }

    private func updateFindingStatus(_ finding: Finding, status: FindingStatus) async {
        let req = UpdateFindingRequest(status: status, severity: nil, remediation: nil)
        if let updated: Finding = try? await client.request(Endpoints.updateFinding(finding.id, req)) {
            if let idx = findings.firstIndex(where: { $0.id == updated.id }) {
                findings[idx] = updated
            }
            cacheManager.store(findings)
            HapticFeedback.success()
            RankManager.shared.awardXP(for: .findingTriaged)
        } else {
            HapticFeedback.error()
        }
    }
}

struct FindingRow: View {
    let finding: Finding
    @State private var isKEV = false
    private let client = APIClient.shared

    var body: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(finding.severity.color)
                .frame(width: 4)
                .cornerRadius(2)
            VStack(alignment: .leading, spacing: 4) {
                Text(finding.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    SeverityBadge(severity: finding.severity)
                    StatusBadge(text: finding.status.label, color: finding.status.color)
                    if isKEV {
                        KEVBadge()
                    }
                    if let cvss = finding.cvssScore {
                        Text("CVSS \(String(format: "%.1f", cvss))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                Text(finding.createdAt.formattedDate)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .padding(.vertical, 4)
        .task {
            guard let cve = finding.cveId else { return }
            let resp: KEVCheckResponse? = try? await client.request(Endpoints.kevCheck(cveId: cve))
            isKEV = resp?.isKnownExploited ?? false
        }
    }
}

struct FindingDetailView: View {
    let finding: Finding
    @State private var timeline: [FindingEvent] = []
    @State private var isUpdating = false
    @State private var selectedStatus: FindingStatus
    @State private var kevEntry: KEVEntry?
    @State private var kevChecked = false
    @State private var showCVSSCalculator = false
    private let client = APIClient.shared

    init(finding: Finding) {
        self.finding = finding
        _selectedStatus = State(initialValue: finding.status)
    }

    var body: some View {
        ZStack {
            Color.cyberBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            SeverityBadge(severity: finding.severity)
                            if let cve = finding.cveId {
                                Text(cve)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.cyberGreen)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.cyberGreen.opacity(0.4), lineWidth: 1))
                            }
                            if kevEntry != nil {
                                KEVBadge()
                            }
                            Spacer()
                            if let cvss = finding.cvssScore {
                                Text("CVSS \(String(format: "%.1f", cvss))")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(finding.severity.color)
                            }
                        }
                        Text(finding.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        if let desc = finding.description {
                            Text(desc)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .cyberCard()

                    // KEV detail panel
                    if let kev = kevEntry {
                        KEVDetailCard(entry: kev)
                    }

                    // Status update
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Status").font(.system(size: 12, design: .monospaced)).foregroundColor(.white.opacity(0.5))
                        Picker("Status", selection: $selectedStatus) {
                            ForEach(FindingStatus.allCases, id: \.self) {
                                Text($0.label).tag($0)
                            }
                        }
                        .pickerStyle(.segmented)
                        Button {
                            Task { await updateStatus() }
                        } label: {
                            Text(isUpdating ? "Saving..." : "Update Status")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.cyberGreen)
                                .foregroundColor(.black)
                                .cornerRadius(8)
                        }
                        .disabled(isUpdating || selectedStatus == finding.status)
                    }
                    .cyberCard()

                    // Remediation
                    if let remediation = finding.remediation {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Remediation", systemImage: "wrench.and.screwdriver")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.cyberGreen)
                            Text(remediation)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .cyberCard()
                    }

                    // Ask AI
                    NavigationLink(destination: AIAssistantView(
                        mode: .explain,
                        prefillContext: AIChatContext(
                            findingTitle: finding.title,
                            findingSeverity: finding.severity.rawValue,
                            findingCveId: finding.cveId,
                            findingCvssScore: finding.cvssScore.map { Double($0) },
                            findingDescription: finding.description,
                            findingRemediation: finding.remediation
                        ),
                        prefillMessage: "Explain this finding and what an attacker could do with it."
                    )) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                            Text("Ask AI to Explain This Finding")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.cyberGreen)
                        .cornerRadius(10)
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Finding")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showCVSSCalculator = true
                    } label: {
                        Label("CVSS Calculator", systemImage: "function")
                    }
                    IntelCardShareButton(finding: finding)
                } label: {
                    Image(systemName: "ellipsis.circle").foregroundColor(.cyberGreen)
                }
            }
        }
        .sheet(isPresented: $showCVSSCalculator) {
            CVSSCalculatorView()
        }
        .task {
            timeline = (try? await client.request(Endpoints.findingTimeline(finding.id))) ?? []
            if let cve = finding.cveId, !kevChecked {
                kevChecked = true
                let resp: KEVCheckResponse? = try? await client.request(Endpoints.kevCheck(cveId: cve))
                if resp?.isKnownExploited == true { kevEntry = resp?.entry }
            }
        }
    }

    private func updateStatus() async {
        isUpdating = true
        defer { isUpdating = false }
        HapticFeedback.statusChange()
        let req = UpdateFindingRequest(status: selectedStatus, severity: nil, remediation: nil)
        if let _: Finding = try? await client.request(Endpoints.updateFinding(finding.id, req)) {
            HapticFeedback.success()
            RankManager.shared.awardXP(for: .findingTriaged)
        } else {
            HapticFeedback.error()
        }
    }
}
