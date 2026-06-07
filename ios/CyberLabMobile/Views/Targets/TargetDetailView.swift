import SwiftUI

struct TargetDetailView: View {
    let target: Target
    @State private var selectedTab = 0
    @State private var showNewScan = false
    @State private var scans: [ScanJobWithTarget] = []
    @State private var findings: [Finding] = []
    @State private var notes: [Note] = []
    @State private var isLoading = true
    private let client = APIClient.shared

    var body: some View {
        ZStack {
            Color.cyberBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                // Header card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: target.type.systemImage)
                            .font(.system(size: 20))
                            .foregroundColor(.cyberGreen)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(target.name)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            Text(target.address)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.cyberGreen.opacity(0.7))
                        }
                        Spacer()
                        VStack(spacing: 4) {
                            StatusBadge(text: target.authorizationStatus.label, color: target.authorizationStatus.color)
                            StatusBadge(text: target.riskLevel.label, color: target.riskLevel.color)
                        }
                    }
                    if let owner = target.owner {
                        Label(owner, systemImage: "person")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding()
                .background(Color.cyberSurface)

                // Tab picker
                Picker("", selection: $selectedTab) {
                    Text("Scans").tag(0)
                    Text("Findings").tag(1)
                    Text("Notes").tag(2)
                    Text("Web").tag(3)
                    Text("OSINT").tag(4)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.cyberBackground)

                // Tab content
                Group {
                    if isLoading && selectedTab < 3 {
                        Spacer()
                        ProgressView().tint(.cyberGreen)
                        Spacer()
                    } else {
                        switch selectedTab {
                        case 0: ScanListTab(scans: scans)
                        case 1: FindingListTab(findings: findings)
                        case 2: NoteListTab(notes: notes, targetId: target.id)
                        case 3: WebAssessmentView(target: target)
                        case 4: OSINTView(target: target)
                        default: EmptyView()
                        }
                    }
                }
            }
        }
        .navigationTitle(target.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showNewScan = true } label: {
                    Image(systemName: "plus.circle.fill").foregroundColor(.cyberGreen)
                }
                .disabled(target.authorizationStatus != .authorized)
            }
        }
        .sheet(isPresented: $showNewScan) {
            NewScanSheet(onCreated: { Task { await loadData() } })
        }
        .task { await loadData() }
    }

    private func loadData() async {
        isLoading = true
        async let s: [ScanJobWithTarget] = (try? client.request(Endpoints.scans(targetId: target.id))) ?? []
        async let f: [Finding] = (try? client.request(Endpoints.findings(targetId: target.id))) ?? []
        async let n: [Note] = (try? client.request(Endpoints.notes(targetId: target.id))) ?? []
        scans = await s; findings = await f; notes = await n
        isLoading = false
    }
}

struct ScanListTab: View {
    let scans: [ScanJobWithTarget]
    var body: some View {
        if scans.isEmpty {
            EmptyTabView(icon: "scanner", message: "No scans yet")
        } else {
            List(scans) { scan in
                NavigationLink(destination: ScanDetailView(scanId: scan.id)) {
                    RecentScanRow(scan: scan)
                }
                .listRowBackground(Color.cyberSurface)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}

struct FindingListTab: View {
    let findings: [Finding]
    var body: some View {
        if findings.isEmpty {
            EmptyTabView(icon: "checkmark.shield", message: "No findings")
        } else {
            List(findings) { f in
                NavigationLink(destination: FindingDetailView(finding: f)) {
                    FindingRow(finding: f)
                }
                .listRowBackground(Color.cyberSurface)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}

struct NoteListTab: View {
    let notes: [Note]
    let targetId: String
    @State private var showAdd = false
    private let client = APIClient.shared

    var body: some View {
        VStack {
            if notes.isEmpty {
                EmptyTabView(icon: "note.text", message: "No notes")
            } else {
                List(notes) { note in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(note.title).font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                        Text(note.body).font(.system(size: 12)).foregroundColor(.white.opacity(0.5)).lineLimit(2)
                        Text(note.createdAt.formattedDate).font(.system(size: 10)).foregroundColor(.white.opacity(0.3))
                    }
                    .listRowBackground(Color.cyberSurface)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }
}

struct EmptyTabView: View {
    let icon: String
    let message: String
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: icon).font(.system(size: 36)).foregroundColor(.cyberGreen.opacity(0.3))
            Text(message).foregroundColor(.white.opacity(0.3)).font(.system(size: 14))
            Spacer()
        }
    }
}
