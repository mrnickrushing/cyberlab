import Foundation

struct ScanProfile: Codable, Identifiable {
    let id: String
    let userId: String?
    let name: String
    let description: String?
    let tool: String
    let flags: String?
    let isDefault: Bool
    let isSystem: Bool
    let createdAt: String
    let updatedAt: String
}

struct CreateScanProfileRequest: Codable {
    let name: String
    let description: String?
    let tool: String
    let flags: String?
}
