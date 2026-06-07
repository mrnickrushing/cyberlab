import Foundation

struct NetworkMap: Codable, Identifiable {
    let id: String
    let userId: String
    let targetId: String?
    let name: String
    let subnet: String
    let scannedAt: String
    let createdAt: String
    var hosts: [NetworkHost]?
}

struct NetworkHost: Codable, Identifiable {
    let id: String
    let networkMapId: String
    let ipAddress: String
    let macAddress: String?
    let hostname: String?
    let vendor: String?
    var isTrusted: Bool
    var isGateway: Bool
    let firstSeen: String
    let lastSeen: String
}

struct CreateNetworkMapRequest: Codable {
    let name: String
    let subnet: String
    let targetId: String?
}

struct UpdateNetworkHostRequest: Codable {
    let isTrusted: Bool?
    let isGateway: Bool?
    let hostname: String?
}

struct DiscoverNetworkResponse: Codable {
    let scanJobId: String
}

extension NetworkHost {
    var displayName: String {
        if let h = hostname, !h.isEmpty { return h }
        return ipAddress
    }

    var trustColor: String {
        if isGateway { return "blue" }
        return isTrusted ? "green" : "orange"
    }
}
