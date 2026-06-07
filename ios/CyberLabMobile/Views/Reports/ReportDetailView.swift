import SwiftUI
import UIKit

struct ReportDetailView: View {
    let targetId: String
    let targetName: String
    @State private var report: FullReport?
    @State private var isLoading = true
    @State private var error: String?
    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var showShareSheet = false
    private let client = APIClient.shared

    var body: some View {
        ZStack {
            Color.cyberBackground.ignoresSafeArea()
            if isLoading {
                ProgressView().tint(.cyberGreen)
            } else if let error {
                ErrorView(message: error) { Task { await load() } }
            } else if let report {
                ScrollView {
                    VStack(spacing: 16) {
                        reportHeader(report)
                        riskScoreCard(report)
                        summaryCard(report)
                        findingsCard(report)
                        if !report.remediations.isEmpty {
                            remediationsCard(report)
                        }
                        scansCard(report)
                        exportButton(report)
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle(targetName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if let report {
                    Button {
                        Task { await exportPDF(report) }
                    } label: {
                        if isExporting {
                            ProgressView().tint(.cyberGreen).scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.up").foregroundColor(.cyberGreen)
                        }
                    }
                    .disabled(isExporting)
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = exportURL {
                ShareSheet(url: url)
            }
        }
        .task { await load() }
    }

    private func reportHeader(_ r: FullReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SECURITY REPORT")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyberGreen)
                    Text(r.target.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Text(r.target.address)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.cyberGreen.opacity(0.4))
            }
            Divider().background(Color.cyberBorder)
            HStack {
                Label(r.generatedAt.formattedFullDate, systemImage: "calendar")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
                if let owner = r.target.owner {
                    Label(owner, systemImage: "person")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }
        .cyberCard()
    }

    private func riskScoreCard(_ r: FullReport) -> some View {
        VStack(spacing: 12) {
            Text("RISK SCORE")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
            ZStack {
                Circle()
                    .stroke(Color.cyberBorder, lineWidth: 10)
                    .frame(width: 120, height: 120)
                Circle()
                    .trim(from: 0, to: CGFloat(r.riskScore) / 100)
                    .stroke(r.riskColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: r.riskScore)
                VStack(spacing: 2) {
                    Text("\(r.riskScore)")
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundColor(r.riskColor)
                    Text("/ 100")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            Text(r.riskLabel)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(r.riskColor)
            Text("Score deducted by open findings: Critical −25 · High −15 · Medium −10 · Low −5 · Info −1")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.3))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .cyberCard()
    }

    private func summaryCard(_ r: FullReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Executive Summary", systemImage: "chart.bar.doc.horizontal")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
            Divider().background(Color.cyberBorder)
            HStack(spacing: 0) {
                summaryStatCell(label: "Open", value: "\(r.summary.openFindings)", color: .red)
                summaryStatCell(label: "Critical", value: "\(r.summary.bySeverity.critical)", color: Color(red: 0.9, green: 0.1, blue: 0.1))
                summaryStatCell(label: "High", value: "\(r.summary.bySeverity.high)", color: .orange)
                summaryStatCell(label: "Medium", value: "\(r.summary.bySeverity.medium)", color: .yellow)
            }
            HStack(spacing: 0) {
                summaryStatCell(label: "Low", value: "\(r.summary.bySeverity.low)", color: .blue)
                summaryStatCell(label: "Info", value: "\(r.summary.bySeverity.info)", color: .gray)
                summaryStatCell(label: "Scans", value: "\(r.summary.totalScans)", color: .cyberGreen)
                summaryStatCell(label: "Tools", value: "\(r.summary.toolsUsed.count)", color: .purple)
            }
            if !r.summary.toolsUsed.isEmpty {
                Divider().background(Color.cyberBorder)
                Text("Tools: " + r.summary.toolsUsed.joined(separator: " · "))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .cyberCard()
    }

    private func summaryStatCell(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }

    private func findingsCard(_ r: FullReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Findings", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Text("\(r.findings.count) total")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.35))
            }
            if r.findings.isEmpty {
                Label("No findings recorded", systemImage: "checkmark.seal.fill")
                    .foregroundColor(.cyberGreen.opacity(0.7))
                    .font(.system(size: 13))
            } else {
                ForEach(r.findings.prefix(30)) { finding in
                    ReportFindingRow(finding: finding)
                }
                if r.findings.count > 30 {
                    Text("+ \(r.findings.count - 30) more findings not shown")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
        }
        .cyberCard()
    }

    private func remediationsCard(_ r: FullReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Remediation Steps", systemImage: "wrench.and.screwdriver.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
            Divider().background(Color.cyberBorder)
            ForEach(r.remediations) { rem in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundColor(FindingSeverity(rawValue: rem.severity)?.color ?? .gray)
                        Text(rem.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    if let steps = rem.remediation {
                        Text(steps)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.55))
                            .padding(.leading, 14)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .cyberCard()
    }

    private func scansCard(_ r: FullReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Scan History", systemImage: "clock.arrow.circlepath")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Text("\(r.scans.count) scans")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.35))
            }
            ForEach(r.scans) { scan in
                HStack {
                    Text("[\(scan.tool.uppercased())]")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyberGreen)
                        .frame(width: 90, alignment: .leading)
                    Text(scan.createdAt.formattedDate)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                    Spacer()
                    StatusBadge(
                        text: scan.status.capitalized,
                        color: scan.status == "completed" ? .cyberGreen : scan.status == "failed" ? .red : .gray
                    )
                }
            }
        }
        .cyberCard()
    }

    private func exportButton(_ r: FullReport) -> some View {
        VStack(spacing: 10) {
            NavigationLink(destination: AIAssistantView(
                mode: .summarize,
                prefillContext: AIChatContext(
                    reportTargetName: r.target.name,
                    reportRiskScore: r.riskScore,
                    reportRiskLabel: r.riskLabel,
                    reportOpenFindings: r.summary.openFindings,
                    reportBySeverity: r.summary.bySeverity,
                    reportToolsUsed: r.summary.toolsUsed,
                    reportTopFindings: r.findings.prefix(15).map {
                        ReportTopFinding(title: $0.title, severity: $0.severity, cveId: $0.cveId)
                    }
                ),
                prefillMessage: "Summarize the security posture of this target and give me a prioritized action plan."
            )) {
                HStack {
                    Image(systemName: "brain.head.profile")
                    Text("Ask AI to Summarize Report")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.cyberGreen)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.cyberGreen.opacity(0.12))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyberGreen.opacity(0.4), lineWidth: 1))
            }

            Button {
                Task { await exportPDF(r) }
            } label: {
                HStack {
                    if isExporting {
                        ProgressView().tint(.black).scaleEffect(0.8)
                    } else {
                        Image(systemName: "square.and.arrow.up.fill")
                    }
                    Text(isExporting ? "Generating PDF…" : "Export as PDF")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.cyberGreen)
                .cornerRadius(10)
            }
            .disabled(isExporting)
        }
    }

    private func load() async {
        isLoading = true; error = nil
        do {
            report = try await client.request(Endpoints.report(targetId))
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    private func exportPDF(_ report: FullReport) async {
        isExporting = true
        exportURL = await PDFExporter.generate(report: report)
        isExporting = false
        if exportURL != nil { showShareSheet = true }
    }
}

// ─── Finding row for report ───────────────────────────────────────────────────

struct ReportFindingRow: View {
    let finding: ReportFinding
    @State private var expanded = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button { withAnimation { expanded.toggle() } } label: {
                HStack(alignment: .top, spacing: 8) {
                    SeverityBadge(severity: finding.severityEnum)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(finding.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                        HStack(spacing: 8) {
                            if let cve = finding.cveId {
                                Text(cve)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.orange)
                            }
                            if let cvss = finding.cvssScore {
                                Text("CVSS \(String(format: "%.1f", cvss))")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.red.opacity(0.8))
                            }
                        }
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.white.opacity(0.3)).font(.system(size: 11))
                }
            }
            if expanded, let desc = finding.description {
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.55))
                    .padding(.leading, 4)
                    .textSelection(.enabled)
            }
        }
        .padding(8)
        .background(Color.cyberBackground)
        .cornerRadius(6)
    }
}

// ─── Share sheet wrapper ──────────────────────────────────────────────────────

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
