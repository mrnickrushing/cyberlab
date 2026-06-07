import Foundation

enum TargetType: String, Codable, CaseIterable {
    case ip
    case domain
    case subnet
    case webapp
}

enum AuthorizationStatus: String, Codable, CaseIterable {
    case authorized
    case unauthorized
    case pending
}

enum RiskLevel: String, Codable, CaseIterable {
    case critical
    case high
    case medium
    case low
    case info
}

struct Target: Codable, Identifiable {
    let id: String
    let userId: String
    let name: String
    let type: TargetType
    let address: String
    let authorizationStatus: AuthorizationStatus
    let riskLevel: RiskLevel
    let tags: [String]?
    let owner: String?
    let notes: String?
    let isArchived: Bool
    let createdAt: String
    let updatedAt: String
}

struct CreateTargetRequest: Codable {
    let name: String
    let type: TargetType
    let address: String
    let authorizationStatus: AuthorizationStatus
    let riskLevel: RiskLevel
    let owner: String?
    let notes: String?
    let tags: [String]?
}

struct UpdateTargetRequest: Codable {
    let name: String?
    let authorizationStatus: AuthorizationStatus?
    let riskLevel: RiskLevel?
    let owner: String?
    let notes: String?
    let tags: [String]?
}
