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
}

struct LabHealth: Codable {
    let status: String
    let workerConnected: Bool
    let dbConnected: Bool
}
