import Foundation

// Writes summary data to shared UserDefaults so the widget can read it
// without needing network access.

struct WidgetSnapshot: Codable {
    var riskScore: Int          // 0-100
    var criticalCount: Int
    var highCount: Int
    var topFindings: [WidgetFinding]   // up to 3
    var lastScanDate: Date?
    var targetName: String
}

struct WidgetFinding: Codable {
    var title: String
    var severity: String        // "critical", "high", "medium", "low"
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
