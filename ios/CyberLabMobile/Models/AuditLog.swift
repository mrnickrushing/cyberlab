import Foundation

struct AuditLog: Codable, Identifiable {
    let id: String
    let userId: String?
    let action: String
    let details: String?
    let ipAddress: String?
    let userAgent: String?
    let createdAt: String
}

struct AuditLogsResponse: Codable {
    let logs: [AuditLog]
    let total: Int
    let page: Int
    let limit: Int
}
