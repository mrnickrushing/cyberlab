import Foundation

struct DashboardStats: Codable {
    let securityScore: Int
    let targetCount: Int
    let activeScans: Int
    let openFindings: Int
    let findingsBySeverity: FindingsBySeverity
    let recentScans: [ScanJobWithTarget]
    let labHealth: LabHealth
}

struct FindingsBySeverity: Codable {
    let critical: Int
    let high: Int
    let medium: Int
    let low: Int
    let info: Int

    private enum CodingKeys: String, CodingKey {
        case critical, high, medium, low, info
    }

    init(from decoder: Decoder) throws {
        // Backend only includes keys for severities that have open findings,
        // so missing keys mean zero — not malformed data.
        let container = try decoder.container(keyedBy: CodingKeys.self)
        critical = try container.decodeIfPresent(Int.self, forKey: .critical) ?? 0
        high = try container.decodeIfPresent(Int.self, forKey: .high) ?? 0
        medium = try container.decodeIfPresent(Int.self, forKey: .medium) ?? 0
        low = try container.decodeIfPresent(Int.self, forKey: .low) ?? 0
        info = try container.decodeIfPresent(Int.self, forKey: .info) ?? 0
    }
}

struct LabHealth: Codable {
    let apiReachable: Bool
    let workerQueueDepth: Int
}
