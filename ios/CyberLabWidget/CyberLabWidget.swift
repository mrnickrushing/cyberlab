import WidgetKit
import SwiftUI

// MARK: - Shared with main app via WidgetDataBridge.swift
// The WidgetKit extension is a separate target and cannot import the main
// app, so the bridge model + reader are duplicated here. Keep in sync with
// ios/CyberLabMobile/Utilities/WidgetDataBridge.swift.

struct WidgetSnapshot: Codable {
    var riskScore: Int
    var criticalCount: Int
    var highCount: Int
    var topFindings: [WidgetFinding]
    var lastScanDate: Date?
    var targetName: String
}

struct WidgetFinding: Codable {
    var title: String
    var severity: String
}

class WidgetDataBridge {
    static let shared = WidgetDataBridge()
    private let suiteName = "group.cyberlab.com"
    private let key = "cyberlab.widget.snapshot"

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    func write(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: key)
    }

    func read() -> WidgetSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}

// MARK: - Timeline

struct CyberLabEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

private let sampleSnapshot = WidgetSnapshot(
    riskScore: 72,
    criticalCount: 2,
    highCount: 3,
    topFindings: [
        WidgetFinding(title: "Outdated OpenSSL on web-01", severity: "critical"),
        WidgetFinding(title: "Exposed admin panel", severity: "high"),
        WidgetFinding(title: "Weak TLS ciphers", severity: "medium")
    ],
    lastScanDate: Date().addingTimeInterval(-600),
    targetName: "prod-network"
)

struct CyberLabProvider: TimelineProvider {
    func placeholder(in context: Context) -> CyberLabEntry {
        CyberLabEntry(date: .now, snapshot: sampleSnapshot)
    }

    func getSnapshot(in context: Context, completion: @escaping (CyberLabEntry) -> Void) {
        let snapshot = context.isPreview ? sampleSnapshot : WidgetDataBridge.shared.read()
        completion(CyberLabEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CyberLabEntry>) -> Void) {
        let entry = CyberLabEntry(date: .now, snapshot: WidgetDataBridge.shared.read())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - Design System (mirrors main app theme)

extension Color {
    static let cyberGreen = Color(red: 0.063, green: 0.725, blue: 0.506)
    static let cyberBackground = Color(red: 0.047, green: 0.063, blue: 0.082)
    static let cyberSurface = Color(red: 0.071, green: 0.098, blue: 0.133)
    static let cyberBorder = Color(red: 0.137, green: 0.188, blue: 0.251)
    static let cyberCyan = Color(red: 0.122, green: 0.890, blue: 1.0)
    static let cyberMagenta = Color(red: 1.0, green: 0.157, blue: 0.635)

    static let severityCritical = Color(red: 1.0, green: 0.231, blue: 0.188)
    static let severityHigh = Color(red: 1.0, green: 0.584, blue: 0.0)
    static let severityMedium = Color(red: 1.0, green: 0.8, blue: 0.0)
    static let severityLow = Color(red: 0.204, green: 0.780, blue: 0.349)
    static let severityInfo = Color(red: 0.557, green: 0.557, blue: 0.576)

    static func severityColor(_ raw: String) -> Color {
        switch raw.lowercased() {
        case "critical": return .severityCritical
        case "high": return .severityHigh
        case "medium": return .severityMedium
        case "low": return .severityLow
        default: return .severityInfo
        }
    }

    /// Risk-score color: red < 40, orange < 70, green >= 70.
    static func riskColor(_ score: Int) -> Color {
        if score < 40 { return .severityCritical }
        if score < 70 { return .severityHigh }
        return .cyberGreen
    }
}
