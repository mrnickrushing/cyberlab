import Foundation

// ─── Diff Change Kind ─────────────────────────────────────────────────────────

enum DiffChangeKind: String, Codable {
    case new
    case gone
    case changed
    case same
}

extension DiffChangeKind {
    var label: String {
        switch self {
        case .new:     return "NEW"
        case .gone:    return "GONE"
        case .changed: return "CHANGED"
        case .same:    return "SAME"
        }
    }
    var color: String {   // returned as hex for easy use
        switch self {
        case .new:     return "cyberGreen"
        case .gone:    return "severityCritical"
        case .changed: return "severityMedium"
        case .same:    return "cyberBorder"
        }
    }
}

// ─── Diff Row ─────────────────────────────────────────────────────────────────

struct DiffRow: Codable, Identifiable {
    let id: String          // deterministic key (e.g. "port:80/tcp")
    let kind: DiffChangeKind
    let label: String       // human-readable subject
    let before: String?     // value in older scan
    let after: String?      // value in newer scan
}

// ─── Scan Diff Response ───────────────────────────────────────────────────────

struct ScanDiff: Codable {
    let scanId: String
    let compareId: String
    let tool: String
    let rows: [DiffRow]

    var newRows:     [DiffRow] { rows.filter { $0.kind == .new     } }
    var goneRows:    [DiffRow] { rows.filter { $0.kind == .gone    } }
    var changedRows: [DiffRow] { rows.filter { $0.kind == .changed } }
    var sameRows:    [DiffRow] { rows.filter { $0.kind == .same    } }

    var hasChanges: Bool { !newRows.isEmpty || !goneRows.isEmpty || !changedRows.isEmpty }
}

// ─── KEV Entry ────────────────────────────────────────────────────────────────

struct KEVEntry: Codable, Identifiable {
    let id: String          // cveId
    let cveId: String
    let vendorProject: String
    let product: String
    let vulnerabilityName: String
    let dateAdded: String
    let requiredAction: String
    let dueDate: String?
    let shortDescription: String?
}

struct KEVCheckResponse: Codable {
    let cveId: String
    let isKnownExploited: Bool
    let entry: KEVEntry?
}
