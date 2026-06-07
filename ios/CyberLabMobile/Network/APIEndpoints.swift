import Foundation

enum HTTPMethod: String {
    case GET, POST, PUT, PATCH, DELETE
}

struct APIEndpoint {
    let path: String
    let method: HTTPMethod
    let body: Encodable?
    let queryItems: [URLQueryItem]?

    init(path: String, method: HTTPMethod = .GET, body: Encodable? = nil, queryItems: [URLQueryItem]? = nil) {
        self.path = path
        self.method = method
        self.body = body
        self.queryItems = queryItems
    }
}

enum Endpoints {
    // Auth
    static func login(_ req: LoginRequest) -> APIEndpoint {
        APIEndpoint(path: "/auth/login", method: .POST, body: req)
    }
    static func register(_ req: RegisterRequest) -> APIEndpoint {
        APIEndpoint(path: "/auth/register", method: .POST, body: req)
    }
    static func refresh(_ req: RefreshTokenRequest) -> APIEndpoint {
        APIEndpoint(path: "/auth/refresh", method: .POST, body: req)
    }
    static var me: APIEndpoint { APIEndpoint(path: "/auth/me") }
    static var logout: APIEndpoint { APIEndpoint(path: "/auth/logout", method: .POST) }
    static var legalAcknowledge: APIEndpoint { APIEndpoint(path: "/auth/legal-acknowledge", method: .POST) }

    // Targets
    static var targets: APIEndpoint { APIEndpoint(path: "/targets") }
    static func createTarget(_ req: CreateTargetRequest) -> APIEndpoint {
        APIEndpoint(path: "/targets", method: .POST, body: req)
    }
    static func target(_ id: String) -> APIEndpoint { APIEndpoint(path: "/targets/\(id)") }
    static func updateTarget(_ id: String, _ req: UpdateTargetRequest) -> APIEndpoint {
        APIEndpoint(path: "/targets/\(id)", method: .PATCH, body: req)
    }
    static func deleteTarget(_ id: String) -> APIEndpoint {
        APIEndpoint(path: "/targets/\(id)", method: .DELETE)
    }
    static func archiveTarget(_ id: String) -> APIEndpoint {
        APIEndpoint(path: "/targets/\(id)/archive", method: .POST)
    }

    // Scans
    static func scans(targetId: String? = nil, status: String? = nil) -> APIEndpoint {
        var items: [URLQueryItem] = []
        if let t = targetId { items.append(URLQueryItem(name: "targetId", value: t)) }
        if let s = status { items.append(URLQueryItem(name: "status", value: s)) }
        return APIEndpoint(path: "/scans", queryItems: items.isEmpty ? nil : items)
    }
    static func createScan(_ req: CreateScanRequest) -> APIEndpoint {
        APIEndpoint(path: "/scans", method: .POST, body: req)
    }
    static func scan(_ id: String) -> APIEndpoint { APIEndpoint(path: "/scans/\(id)") }
    static func cancelScan(_ id: String) -> APIEndpoint {
        APIEndpoint(path: "/scans/\(id)", method: .DELETE)
    }
    static func scanResults(_ id: String) -> APIEndpoint {
        APIEndpoint(path: "/scans/\(id)/results")
    }

    // Scan profiles
    static var scanProfiles: APIEndpoint { APIEndpoint(path: "/scan-profiles") }
    static func createScanProfile(_ req: CreateScanProfileRequest) -> APIEndpoint {
        APIEndpoint(path: "/scan-profiles", method: .POST, body: req)
    }
    static func deleteScanProfile(_ id: String) -> APIEndpoint {
        APIEndpoint(path: "/scan-profiles/\(id)", method: .DELETE)
    }

    // Findings
    static func findings(targetId: String? = nil, severity: String? = nil, status: String? = nil) -> APIEndpoint {
        var items: [URLQueryItem] = []
        if let t = targetId { items.append(URLQueryItem(name: "targetId", value: t)) }
        if let s = severity { items.append(URLQueryItem(name: "severity", value: s)) }
        if let s = status { items.append(URLQueryItem(name: "status", value: s)) }
        return APIEndpoint(path: "/findings", queryItems: items.isEmpty ? nil : items)
    }
    static func createFinding(_ req: CreateFindingRequest) -> APIEndpoint {
        APIEndpoint(path: "/findings", method: .POST, body: req)
    }
    static func finding(_ id: String) -> APIEndpoint { APIEndpoint(path: "/findings/\(id)") }
    static func updateFinding(_ id: String, _ req: UpdateFindingRequest) -> APIEndpoint {
        APIEndpoint(path: "/findings/\(id)", method: .PATCH, body: req)
    }
    static func deleteFinding(_ id: String) -> APIEndpoint {
        APIEndpoint(path: "/findings/\(id)", method: .DELETE)
    }
    static func findingTimeline(_ id: String) -> APIEndpoint {
        APIEndpoint(path: "/findings/\(id)/timeline")
    }

    // Notes
    static func notes(targetId: String? = nil) -> APIEndpoint {
        var items: [URLQueryItem] = []
        if let t = targetId { items.append(URLQueryItem(name: "targetId", value: t)) }
        return APIEndpoint(path: "/notes", queryItems: items.isEmpty ? nil : items)
    }
    static func createNote(_ req: CreateNoteRequest) -> APIEndpoint {
        APIEndpoint(path: "/notes", method: .POST, body: req)
    }
    static func note(_ id: String) -> APIEndpoint { APIEndpoint(path: "/notes/\(id)") }
    static func updateNote(_ id: String, _ req: UpdateNoteRequest) -> APIEndpoint {
        APIEndpoint(path: "/notes/\(id)", method: .PATCH, body: req)
    }
    static func deleteNote(_ id: String) -> APIEndpoint {
        APIEndpoint(path: "/notes/\(id)", method: .DELETE)
    }

    // Audit
    static func audit(page: Int = 1, limit: Int = 50) -> APIEndpoint {
        APIEndpoint(path: "/audit", queryItems: [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ])
    }

    // Dashboard
    static var dashboard: APIEndpoint { APIEndpoint(path: "/dashboard") }

    // Health
    static var health: APIEndpoint { APIEndpoint(path: "/healthz") }
}
