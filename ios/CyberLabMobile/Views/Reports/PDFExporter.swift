import UIKit
import Foundation

enum PDFExporter {
    @MainActor
    static func generate(report: FullReport) async -> URL? {
        let pageW: CGFloat = 595.2
        let pageH: CGFloat = 841.8
        let margin: CGFloat = 40
        let innerW = pageW - margin * 2

        let fileName = "CyberLab_\(report.target.name.replacingOccurrences(of: " ", with: "_")).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH))

        do {
            try renderer.writePDF(to: url) { ctx in
                ctx.beginPage()
                var y: CGFloat = margin

                // ── Header bar ──────────────────────────────────────────────
                let green = UIColor(red: 0.063, green: 0.725, blue: 0.506, alpha: 1)
                green.setFill()
                UIBezierPath(roundedRect: CGRect(x: margin, y: y, width: innerW, height: 60), cornerRadius: 8).fill()

                "CYBERLAB".draw(
                    in: CGRect(x: margin + 12, y: y + 8, width: 200, height: 20),
                    withAttributes: [.font: UIFont.monospacedSystemFont(ofSize: 11, weight: .bold), .foregroundColor: UIColor.black]
                )
                "Security Report".draw(
                    in: CGRect(x: margin + 12, y: y + 28, width: 300, height: 20),
                    withAttributes: [.font: UIFont.boldSystemFont(ofSize: 16), .foregroundColor: UIColor.black]
                )
                let dateStr = report.generatedAt.prefix(10)
                String(dateStr).draw(
                    in: CGRect(x: pageW - margin - 120, y: y + 20, width: 110, height: 20),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 11), .foregroundColor: UIColor.black]
                )
                y += 76

                // ── Target info ─────────────────────────────────────────────
                y = drawSection(title: "TARGET", y: y, margin: margin, innerW: innerW)
                y = drawKV("Name",    report.target.name,    y: y, margin: margin, innerW: innerW)
                y = drawKV("Address", report.target.address, y: y, margin: margin, innerW: innerW)
                y = drawKV("Type",    report.target.type,    y: y, margin: margin, innerW: innerW)
                if let owner = report.target.owner {
                    y = drawKV("Owner", owner, y: y, margin: margin, innerW: innerW)
                }
                y += 10

                // ── Risk score ──────────────────────────────────────────────
                y = drawSection(title: "RISK SCORE", y: y, margin: margin, innerW: innerW)
                let scoreColor: UIColor = report.riskScore >= 80 ? green
                    : report.riskScore >= 60 ? .systemYellow
                    : report.riskScore >= 40 ? .systemOrange : .systemRed
                scoreColor.setFill()
                UIBezierPath(roundedRect: CGRect(x: margin, y: y, width: 80, height: 32), cornerRadius: 6).fill()
                "\(report.riskScore)/100".draw(
                    in: CGRect(x: margin + 6, y: y + 6, width: 68, height: 20),
                    withAttributes: [.font: UIFont.monospacedSystemFont(ofSize: 16, weight: .bold), .foregroundColor: UIColor.white]
                )
                report.riskLabel.draw(
                    in: CGRect(x: margin + 90, y: y + 8, width: 200, height: 20),
                    withAttributes: [.font: UIFont.boldSystemFont(ofSize: 14), .foregroundColor: scoreColor]
                )
                y += 46

                // ── Summary ─────────────────────────────────────────────────
                y = drawSection(title: "SUMMARY", y: y, margin: margin, innerW: innerW)
                let s = report.summary
                y = drawKV("Open Findings", "\(s.openFindings) of \(s.totalFindings)", y: y, margin: margin, innerW: innerW)
                y = drawKV("By Severity",
                    "Critical \(s.bySeverity.critical)  ·  High \(s.bySeverity.high)  ·  Medium \(s.bySeverity.medium)  ·  Low \(s.bySeverity.low)  ·  Info \(s.bySeverity.info)",
                    y: y, margin: margin, innerW: innerW)
                y = drawKV("Scans Run",   "\(s.totalScans)",              y: y, margin: margin, innerW: innerW)
                y = drawKV("Tools Used",  s.toolsUsed.joined(separator: ", "), y: y, margin: margin, innerW: innerW)
                y += 10

                // ── Findings (paginating if needed) ─────────────────────────
                y = drawSection(title: "FINDINGS", y: y, margin: margin, innerW: innerW)
                for finding in report.findings {
                    // new page if needed
                    if y > pageH - 120 {
                        ctx.beginPage()
                        y = margin
                    }
                    y = drawFindingRow(finding, y: y, margin: margin, innerW: innerW)
                }
                y += 10

                // ── Remediations ─────────────────────────────────────────────
                if !report.remediations.isEmpty {
                    if y > pageH - 200 { ctx.beginPage(); y = margin }
                    y = drawSection(title: "REMEDIATION STEPS", y: y, margin: margin, innerW: innerW)
                    for rem in report.remediations {
                        if y > pageH - 80 { ctx.beginPage(); y = margin }
                        y = drawRemediation(rem, y: y, margin: margin, innerW: innerW)
                    }
                }

                // ── Footer ───────────────────────────────────────────────────
                "Generated by CyberLab Mobile  ·  For authorized use only".draw(
                    in: CGRect(x: margin, y: pageH - 28, width: innerW, height: 16),
                    withAttributes: [
                        .font: UIFont.systemFont(ofSize: 9),
                        .foregroundColor: UIColor.systemGray,
                    ]
                )
            }
            return url
        } catch {
            return nil
        }
    }

    // ─── Drawing helpers ──────────────────────────────────────────────────────

    @discardableResult
    private static func drawSection(title: String, y: CGFloat, margin: CGFloat, innerW: CGFloat) -> CGFloat {
        let green = UIColor(red: 0.063, green: 0.725, blue: 0.506, alpha: 1)
        title.draw(
            in: CGRect(x: margin, y: y, width: innerW, height: 16),
            withAttributes: [
                .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .bold),
                .foregroundColor: green,
            ]
        )
        green.withAlphaComponent(0.3).setFill()
        UIBezierPath(rect: CGRect(x: margin, y: y + 18, width: innerW, height: 1)).fill()
        return y + 26
    }

    @discardableResult
    private static func drawKV(_ key: String, _ value: String, y: CGFloat, margin: CGFloat, innerW: CGFloat) -> CGFloat {
        key.draw(
            in: CGRect(x: margin, y: y, width: 100, height: 16),
            withAttributes: [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.systemGray]
        )
        value.draw(
            in: CGRect(x: margin + 105, y: y, width: innerW - 105, height: 16),
            withAttributes: [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.darkText]
        )
        return y + 18
    }

    @discardableResult
    private static func drawFindingRow(_ f: ReportFinding, y: CGFloat, margin: CGFloat, innerW: CGFloat) -> CGFloat {
        let sevColor: UIColor = {
            switch f.severity {
            case "critical": return .systemRed
            case "high":     return .systemOrange
            case "medium":   return .systemYellow
            case "low":      return .systemBlue
            default:         return .systemGray
            }
        }()
        // Severity dot
        sevColor.setFill()
        UIBezierPath(ovalIn: CGRect(x: margin, y: y + 4, width: 8, height: 8)).fill()
        // Title
        f.title.draw(
            in: CGRect(x: margin + 14, y: y, width: innerW - 80, height: 16),
            withAttributes: [.font: UIFont.boldSystemFont(ofSize: 10), .foregroundColor: UIColor.darkText]
        )
        // Severity label
        f.severity.uppercased().draw(
            in: CGRect(x: pageW - margin - 60, y: y, width: 55, height: 14),
            withAttributes: [.font: UIFont.monospacedSystemFont(ofSize: 9, weight: .bold), .foregroundColor: sevColor]
        )
        // CVE / CVSS
        var metaStr = ""
        if let cve = f.cveId { metaStr += cve }
        if let cvss = f.cvssScore { metaStr += (metaStr.isEmpty ? "" : "  ·  ") + "CVSS \(String(format: "%.1f", cvss))" }
        if !metaStr.isEmpty {
            metaStr.draw(
                in: CGRect(x: margin + 14, y: y + 16, width: innerW - 80, height: 14),
                withAttributes: [.font: UIFont.monospacedSystemFont(ofSize: 9, weight: .regular), .foregroundColor: UIColor.systemOrange]
            )
        }
        let extraH: CGFloat = metaStr.isEmpty ? 0 : 14
        return y + 20 + extraH + 4
    }

    @discardableResult
    private static func drawRemediation(_ r: ReportRemediation, y: CGFloat, margin: CGFloat, innerW: CGFloat) -> CGFloat {
        r.title.draw(
            in: CGRect(x: margin, y: y, width: innerW, height: 14),
            withAttributes: [.font: UIFont.boldSystemFont(ofSize: 10), .foregroundColor: UIColor.darkText]
        )
        var newY = y + 16
        if let steps = r.remediation {
            let truncated = steps.count > 200 ? String(steps.prefix(200)) + "…" : steps
            let rect = CGRect(x: margin + 10, y: newY, width: innerW - 10, height: 100)
            truncated.draw(
                in: rect,
                withAttributes: [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: UIColor.systemGray]
            )
            let approxLines = max(1, truncated.count / 80)
            newY += CGFloat(approxLines) * 12 + 4
        }
        return newY + 6
    }

    private static var pageW: CGFloat { 595.2 }
}
