import Foundation

enum FindingSeverity: String, Codable, CaseIterable {
    case critical
    case high
    case medium
    case low
    case info
}

enum FindingStatus: String, Codable, CaseIterable {
    case open
    case fixed
    case acceptedRisk = "accepted_risk"
    case falsePositive = "false_positive"
}

struct Finding: Codable, Identifiable {
    let id: String
    let userId: String
    let targetId: String
    let scanJobId: String?
    let title: String
    let severity: FindingSeverity
    let status: FindingStatus
    let cvssScore: Double?
    let cveId: String?
    let description: String?
    let remediation: String?
    let createdAt: String
    let updatedAt: String
}

struct CreateFindingRequest: Codable {
    let targetId: String
    let title: String
    let severity: FindingSeverity
    let description: String?
    let remediation: String?
    let cvssScore: Double?
    let cveId: String?
}

struct UpdateFindingRequest: Codable {
    let status: FindingStatus?
    let severity: FindingSeverity?
    let remediation: String?
}

struct FindingEvent: Codable, Identifiable {
    let id: String
    let findingId: String
    let userId: String
    let action: String
    let fromStatus: String?
    let toStatus: String?
    let note: String?
    let createdAt: String
}
