import SwiftUI

struct OperatorProfileView: View {
    @StateObject private var rank = RankManager.shared
    @AppStorage("reportsExportedCount") private var reportsExported = 0

    @State private var totalScans = 0
    @State private var totalFindings = 0
    @State private var totalTargets = 0
    @State private var isLoading = true
    private let client = APIClient.shared

    var body: some View {
        ZStack {
            Color.cyberBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    rankCard
                    progressCard
                    statsGrid
                    eventsCard
                }
                .padding(16)
            }
        }
        .navigationTitle("Operator Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadStats() }
    }

    // ─── Rank badge ─────────────────────────────────────────────────────────

    private var rankCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.cyberGreen.opacity(0.12))
                    .frame(width: 96, height: 96)
                Image(systemName: rank.currentRank.icon)
                    .font(.system(size: 42))
                    .foregroundColor(.cyberGreen)
                    .neonGlow(.cyberGreen, radius: 8)
            }
            Text(rank.currentRank.title.uppercased())
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .foregroundColor(.cyberGreen)
                .kerning(1)
            Text("\(rank.totalXP) XP")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .cyberCard()
        .hudFrame(color: .cyberGreen.opacity(0.6))
    }

    // ─── XP progress ────────────────────────────────────────────────────────

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("RANK PROGRESS")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                if let next = rank.nextRank {
                    Text("Next: \(next.title)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.cyberGreen.opacity(0.8))
                } else {
                    Text("MAX RANK")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyberGreen)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.cyberBorder).frame(height: 10)
                    Capsule()
                        .fill(Color.cyberGreen)
                        .frame(width: max(6, geo.size.width * rank.progressToNextRank), height: 10)
                        .neonGlow(.cyberGreen, radius: 5)
                        .animation(.easeInOut(duration: 0.8), value: rank.progressToNextRank)
                }
            }
            .frame(height: 10)
            if rank.nextRank != nil {
                Text("\(rank.totalXP) / \(rank.nextRank!.threshold) XP to next rank")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .cyberCard()
    }

    // ─── Stats ──────────────────────────────────────────────────────────────

    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OPERATIONS")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
            HStack(spacing: 12) {
                profileStat("Scans", "\(totalScans)", "scanner", .cyberGreen)
                profileStat("Findings", "\(totalFindings)", "exclamationmark.triangle", .severityHigh)
            }
            HStack(spacing: 12) {
                profileStat("Reports", "\(reportsExported)", "doc.text.fill", .cyberCyan)
                profileStat("Targets", "\(totalTargets)", "target", .cyberMagenta)
            }
        }
        .cyberCard()
    }

    private func profileStat(_ label: String, _ value: String, _ icon: String, _ color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 18)).foregroundColor(color)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Text(label).font(.system(size: 10)).foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.cyberBackground)
        .cornerRadius(8)
    }

    // ─── Recent XP events ─────────────────────────────────────────────────────

    private var eventsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECENT XP")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
            if rank.recentEvents.isEmpty {
                Text("No XP earned yet — run a scan to get started")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.35))
            } else {
                ForEach(rank.recentEvents) { entry in
                    HStack(spacing: 10) {
                        Image(systemName: entry.event.icon)
                            .font(.system(size: 13))
                            .foregroundColor(.cyberGreen)
                            .frame(width: 22)
                        Text(entry.event.label)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                        Text("+\(entry.xp)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyberGreen)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .cyberCard()
    }

    private func loadStats() async {
        async let scans: [ScanJobWithTarget] = (try? client.request(Endpoints.scans())) ?? []
        async let findings: [Finding] = (try? client.request(Endpoints.findings())) ?? []
        async let targets: [Target] = (try? client.request(Endpoints.targets)) ?? []
        let s = await scans, f = await findings, t = await targets
        totalScans = s.count
        totalFindings = f.count
        totalTargets = t.filter { !$0.isArchived }.count
        isLoading = false
    }
}
