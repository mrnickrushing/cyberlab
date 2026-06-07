import SwiftUI

struct ReportsView: View {
    @State private var summaries: [ReportSummary] = []
    @State private var isLoading = true
    @State private var error: String?
    private let client = APIClient.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cyberBackground.ignoresSafeArea()
                Group {
                    if isLoading {
                        ProgressView().tint(.cyberGreen)
                    } else if let error {
                        ErrorView(message: error) { Task { await load() } }
                    } else if summaries.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 44))
                                .foregroundColor(.cyberGreen.opacity(0.4))
                            Text("No targets to report on")
                                .foregroundColor(.white.opacity(0.5))
                            Text("Add and scan a target to generate a report")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .padding()
                    } else {
                        List {
                            ForEach(summaries) { summary in
                                NavigationLink(destination: ReportDetailView(targetId: summary.targetId, targetName: summary.targetName)) {
                                    ReportSummaryRow(summary: summary)
                                }
                                .listRowBackground(Color.cyberSurface)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Reports")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await load() } } label: {
                        Image(systemName: "arrow.clockwise").foregroundColor(.cyberGreen)
                    }
                }
            }
            .refreshable { await load() }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true; error = nil
        do {
            summaries = try await client.request(Endpoints.reports)
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }
}

struct ReportSummaryRow: View {
    let summary: ReportSummary
    var body: some View {
        HStack(spacing: 12) {
            // Risk gauge
            ZStack {
                Circle()
                    .stroke(Color.cyberBorder, lineWidth: 3)
                    .frame(width: 48, height: 48)
                Circle()
                    .trim(from: 0, to: CGFloat(summary.riskScore) / 100)
                    .stroke(summary.riskColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(-90))
                Text("\(summary.riskScore)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(summary.riskColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.targetName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(summary.targetAddress)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.45))
                HStack(spacing: 8) {
                    if summary.bySeverity.critical > 0 {
                        MiniSevChip(count: summary.bySeverity.critical, color: Color(red: 0.9, green: 0.1, blue: 0.1))
                    }
                    if summary.bySeverity.high > 0 {
                        MiniSevChip(count: summary.bySeverity.high, color: .orange)
                    }
                    if summary.bySeverity.medium > 0 {
                        MiniSevChip(count: summary.bySeverity.medium, color: .yellow)
                    }
                    if summary.bySeverity.low > 0 {
                        MiniSevChip(count: summary.bySeverity.low, color: .blue)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                StatusBadge(text: summary.riskLabel, color: summary.riskColor)
                Text("\(summary.totalScans) scans")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.35))
            }
        }
        .padding(.vertical, 6)
    }
}

struct MiniSevChip: View {
    let count: Int
    let color: Color
    var body: some View {
        Text("\(count)")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .cornerRadius(3)
    }
}
