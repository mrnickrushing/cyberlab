import WidgetKit
import SwiftUI

// MARK: - Circuit / grid pattern overlay

struct CircuitGridOverlay: View {
    var spacing: CGFloat = 14
    var opacity: Double = 0.06

    var body: some View {
        GeometryReader { geo in
            Path { path in
                var x: CGFloat = 0
                while x < geo.size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geo.size.height))
                    x += spacing
                }
                var y: CGFloat = 0
                while y < geo.size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    y += spacing
                }
            }
            .stroke(Color.cyberGreen.opacity(opacity), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Shared bits

private func lastScanText(_ date: Date?) -> String {
    guard let date else { return "No scans yet" }
    let fmt = RelativeDateTimeFormatter()
    fmt.unitsStyle = .abbreviated
    return "Last scan: \(fmt.localizedString(for: date, relativeTo: Date()))"
}

struct RiskScoreBlock: View {
    let snapshot: WidgetSnapshot?

    var body: some View {
        let score = snapshot?.riskScore ?? 0
        let critical = snapshot?.criticalCount ?? 0

        VStack(spacing: 4) {
            Text("CYBERLAB")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .kerning(1.5)
                .foregroundColor(.cyberGreen)

            Text("\(score)")
                .font(.system(size: 44, weight: .bold, design: .monospaced))
                .foregroundColor(.riskColor(score))
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            if critical > 0 {
                Text("\(critical) CRITICAL")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(.severityCritical)
            } else {
                Text("SECURE")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(.cyberGreen)
            }
        }
    }
}

// MARK: - Small widget

struct CyberLabSmallView: View {
    let entry: CyberLabEntry

    var body: some View {
        ZStack {
            Color.cyberBackground
            CircuitGridOverlay()
            RiskScoreBlock(snapshot: entry.snapshot)
                .padding()
        }
    }
}

// MARK: - Medium widget

struct CyberLabMediumView: View {
    let entry: CyberLabEntry

    var body: some View {
        ZStack {
            Color.cyberBackground
            CircuitGridOverlay()

            HStack(spacing: 0) {
                RiskScoreBlock(snapshot: entry.snapshot)
                    .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color.cyberBorder)
                    .frame(width: 1)
                    .padding(.vertical, 12)

                VStack(alignment: .leading, spacing: 6) {
                    let findings = entry.snapshot?.topFindings ?? []
                    if findings.isEmpty {
                        Text("No open findings")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.cyberGreen.opacity(0.7))
                    } else {
                        ForEach(Array(findings.prefix(3).enumerated()), id: \.offset) { _, finding in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.severityColor(finding.severity))
                                    .frame(width: 7, height: 7)
                                Text(finding.title)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.85))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }
                    }

                    Spacer(minLength: 0)

                    Text(lastScanText(entry.snapshot?.lastScanDate))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
            }
        }
    }
}

// MARK: - Lock screen circular widget

struct CyberLabLockScreenView: View {
    let entry: CyberLabEntry

    var body: some View {
        let count = entry.snapshot?.criticalCount ?? 0
        let tint = count > 0 ? Color.severityCritical : Color.cyberGreen

        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text("\(count)")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(tint)
                Text("CRIT")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(tint)
            }
        }
        .widgetAccentable()
    }
}
