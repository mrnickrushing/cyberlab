import Foundation

enum ScanStatus: String, Codable {
    case pending
    case running
    case completed
    case failed
    case cancelled
}

struct ScanJob: Codable, Identifiable {
    let id: String
    let userId: String
    let targetId: String
    let tool: String
    let flags: String?
    let status: ScanStatus
    let progress: Int?
    let workerJobId: String?
    let errorMessage: String?
    let createdAt: String
    let startedAt: String?
    let completedAt: String?
    let updatedAt: String
}

struct ScanJobWithTarget: Codable, Identifiable {
    let id: String
    let userId: String
    let targetId: String
    let tool: String
    let flags: String?
    let status: ScanStatus
    let progress: Int?
    let errorMessage: String?
    let createdAt: String
    let startedAt: String?
    let completedAt: String?
    let updatedAt: String
    let targetName: String?
    let targetAddress: String?
}

struct CreateScanRequest: Codable {
    let targetId: String
    let tool: String
    let flags: String?
    let profileId: String?
}

struct ScanResult: Codable {
    let id: String
    let scanJobId: String
    let rawOutput: String?
    let parsedData: ParsedData?
    let createdAt: String
}

struct ParsedData: Codable {
    let hosts: [NmapHost]?
    let findings: [AnyCodable]?
    let records: [String]?
}

// Type-erased Codable for dynamic JSON
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if let arr = try? container.decode([AnyCodable].self) {
            value = arr.map { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let s as String: try container.encode(s)
        case let i as Int: try container.encode(i)
        case let d as Double: try container.encode(d)
        case let b as Bool: try container.encode(b)
        default: try container.encodeNil()
        }
    }
}

struct NmapHost: Codable {
    let address: String?
    let status: String?
    let hostname: String?
    let os: String?
    let ports: [NmapPort]?
}

struct NmapPort: Codable {
    let port: Int
    let protocol: String?
    let state: String?
    let service: String?
    let product: String?
    let version: String?
}
