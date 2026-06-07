import Foundation

struct Note: Codable, Identifiable {
    let id: String
    let userId: String
    let targetId: String?
    let title: String
    let body: String
    let tags: [String]?
    let createdAt: String
    let updatedAt: String
}

struct CreateNoteRequest: Codable {
    let title: String
    let body: String
    let targetId: String?
    let tags: [String]?
}

struct UpdateNoteRequest: Codable {
    let title: String?
    let body: String?
    let tags: [String]?
}
