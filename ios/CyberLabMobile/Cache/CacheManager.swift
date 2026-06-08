import Foundation
import SwiftData

// MARK: - SwiftData Cached Models
//
// These mirror the API models (Target, Finding, ScanJob, Note) for offline
// stale-while-revalidate caching. Scalar fields are stored directly; arrays and
// optionals that don't map cleanly to SwiftData are persisted as JSON-encoded Data.

@Model
final class CachedTarget {
    @Attribute(.unique) var id: String
    var userId: String
    var name: String
    var type: String
    var address: String
    var authorizationStatus: String
    var riskLevel: String
    var tagsJSON: Data?
    var owner: String?
    var notes: String?
    var isArchived: Bool
    var createdAt: String
    var updatedAt: String
    var cachedAt: Date

    init(from t: Target) {
        id = t.id
        userId = t.userId
        name = t.name
        type = t.type.rawValue
        address = t.address
        authorizationStatus = t.authorizationStatus.rawValue
        riskLevel = t.riskLevel.rawValue
        tagsJSON = t.tags.flatMap { try? JSONEncoder().encode($0) }
        owner = t.owner
        notes = t.notes
        isArchived = t.isArchived
        createdAt = t.createdAt
        updatedAt = t.updatedAt
        cachedAt = Date()
    }

    func toModel() -> Target {
        Target(
            id: id,
            userId: userId,
            name: name,
            type: TargetType(rawValue: type) ?? .ip,
            address: address,
            authorizationStatus: AuthorizationStatus(rawValue: authorizationStatus) ?? .pending,
            riskLevel: RiskLevel(rawValue: riskLevel) ?? .info,
            tags: tagsJSON.flatMap { try? JSONDecoder().decode([String].self, from: $0) },
            owner: owner,
            notes: notes,
            isArchived: isArchived,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

@Model
final class CachedFinding {
    @Attribute(.unique) var id: String
    var userId: String
    var targetId: String
    var scanJobId: String?
    var title: String
    var severity: String
    var status: String
    var cvssScore: Double?
    var cveId: String?
    var findingDescription: String?
    var remediation: String?
    var createdAt: String
    var updatedAt: String
    var cachedAt: Date

    init(from f: Finding) {
        id = f.id
        userId = f.userId
        targetId = f.targetId
        scanJobId = f.scanJobId
        title = f.title
        severity = f.severity.rawValue
        status = f.status.rawValue
        cvssScore = f.cvssScore
        cveId = f.cveId
        findingDescription = f.description
        remediation = f.remediation
        createdAt = f.createdAt
        updatedAt = f.updatedAt
        cachedAt = Date()
    }

    func toModel() -> Finding {
        Finding(
            id: id,
            userId: userId,
            targetId: targetId,
            scanJobId: scanJobId,
            title: title,
            severity: FindingSeverity(rawValue: severity) ?? .info,
            status: FindingStatus(rawValue: status) ?? .open,
            cvssScore: cvssScore,
            cveId: cveId,
            description: findingDescription,
            remediation: remediation,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

@Model
final class CachedScan {
    @Attribute(.unique) var id: String
    var userId: String
    var targetId: String
    var tool: String
    var flags: String?
    var status: String
    var progress: Int?
    var workerJobId: String?
    var errorMessage: String?
    var createdAt: String
    var startedAt: String?
    var completedAt: String?
    var updatedAt: String
    var cachedAt: Date

    init(from s: ScanJob) {
        id = s.id
        userId = s.userId
        targetId = s.targetId
        tool = s.tool
        flags = s.flags
        status = s.status.rawValue
        progress = s.progress
        workerJobId = s.workerJobId
        errorMessage = s.errorMessage
        createdAt = s.createdAt
        startedAt = s.startedAt
        completedAt = s.completedAt
        updatedAt = s.updatedAt
        cachedAt = Date()
    }

    func toModel() -> ScanJob {
        ScanJob(
            id: id,
            userId: userId,
            targetId: targetId,
            tool: tool,
            flags: flags,
            status: ScanStatus(rawValue: status) ?? .pending,
            progress: progress,
            workerJobId: workerJobId,
            errorMessage: errorMessage,
            createdAt: createdAt,
            startedAt: startedAt,
            completedAt: completedAt,
            updatedAt: updatedAt
        )
    }
}

@Model
final class CachedNote {
    @Attribute(.unique) var id: String
    var userId: String
    var targetId: String?
    var title: String
    var body: String
    var tagsJSON: Data?
    var createdAt: String
    var updatedAt: String
    var cachedAt: Date

    init(from n: Note) {
        id = n.id
        userId = n.userId
        targetId = n.targetId
        title = n.title
        body = n.body
        tagsJSON = n.tags.flatMap { try? JSONEncoder().encode($0) }
        createdAt = n.createdAt
        updatedAt = n.updatedAt
        cachedAt = Date()
    }

    func toModel() -> Note {
        Note(
            id: id,
            userId: userId,
            targetId: targetId,
            title: title,
            body: body,
            tags: tagsJSON.flatMap { try? JSONDecoder().decode([String].self, from: $0) },
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// MARK: - Cache Manager
//
// Stale-while-revalidate offline cache backed by SwiftData. Views read cached
// data synchronously for an instant first paint, then fetch fresh data from the
// API and call `store(_:)` to persist the new snapshot.

@MainActor
final class CacheManager: ObservableObject {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: Reads

    func cachedTargets() -> [Target] {
        let descriptor = FetchDescriptor<CachedTarget>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        let rows = (try? context.fetch(descriptor)) ?? []
        return rows.map { $0.toModel() }
    }

    func cachedFindings(for targetId: String) -> [Finding] {
        let descriptor = FetchDescriptor<CachedFinding>(
            predicate: #Predicate { $0.targetId == targetId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let rows = (try? context.fetch(descriptor)) ?? []
        return rows.map { $0.toModel() }
    }

    func cachedFindings() -> [Finding] {
        let descriptor = FetchDescriptor<CachedFinding>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let rows = (try? context.fetch(descriptor)) ?? []
        return rows.map { $0.toModel() }
    }

    func cachedScans(for targetId: String) -> [ScanJob] {
        let descriptor = FetchDescriptor<CachedScan>(
            predicate: #Predicate { $0.targetId == targetId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let rows = (try? context.fetch(descriptor)) ?? []
        return rows.map { $0.toModel() }
    }

    func cachedNotes(for targetId: String) -> [Note] {
        let descriptor = FetchDescriptor<CachedNote>(
            predicate: #Predicate { $0.targetId == targetId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let rows = (try? context.fetch(descriptor)) ?? []
        return rows.map { $0.toModel() }
    }

    func cachedNotes() -> [Note] {
        let descriptor = FetchDescriptor<CachedNote>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let rows = (try? context.fetch(descriptor)) ?? []
        return rows.map { $0.toModel() }
    }

    // MARK: Writes

    func store(_ targets: [Target]) {
        try? context.delete(model: CachedTarget.self)
        for t in targets { context.insert(CachedTarget(from: t)) }
        save()
    }

    func store(_ findings: [Finding], for targetId: String) {
        let descriptor = FetchDescriptor<CachedFinding>(predicate: #Predicate { $0.targetId == targetId })
        if let existing = try? context.fetch(descriptor) {
            for row in existing { context.delete(row) }
        }
        for f in findings { context.insert(CachedFinding(from: f)) }
        save()
    }

    func store(_ findings: [Finding]) {
        try? context.delete(model: CachedFinding.self)
        for f in findings { context.insert(CachedFinding(from: f)) }
        save()
    }

    func store(_ scans: [ScanJob], for targetId: String) {
        let descriptor = FetchDescriptor<CachedScan>(predicate: #Predicate { $0.targetId == targetId })
        if let existing = try? context.fetch(descriptor) {
            for row in existing { context.delete(row) }
        }
        for s in scans { context.insert(CachedScan(from: s)) }
        save()
    }

    func store(_ notes: [Note]) {
        try? context.delete(model: CachedNote.self)
        for n in notes { context.insert(CachedNote(from: n)) }
        save()
    }

    func storeNotes(_ notes: [Note], for targetId: String) {
        let descriptor = FetchDescriptor<CachedNote>(predicate: #Predicate { $0.targetId == targetId })
        if let existing = try? context.fetch(descriptor) {
            for row in existing { context.delete(row) }
        }
        for n in notes { context.insert(CachedNote(from: n)) }
        save()
    }

    // MARK: Invalidation

    func invalidateAll() {
        try? context.delete(model: CachedTarget.self)
        try? context.delete(model: CachedFinding.self)
        try? context.delete(model: CachedScan.self)
        try? context.delete(model: CachedNote.self)
        save()
    }

    func invalidate(targetId: String) {
        if let findings = try? context.fetch(FetchDescriptor<CachedFinding>(predicate: #Predicate { $0.targetId == targetId })) {
            for row in findings { context.delete(row) }
        }
        if let scans = try? context.fetch(FetchDescriptor<CachedScan>(predicate: #Predicate { $0.targetId == targetId })) {
            for row in scans { context.delete(row) }
        }
        if let notes = try? context.fetch(FetchDescriptor<CachedNote>(predicate: #Predicate { $0.targetId == targetId })) {
            for row in notes { context.delete(row) }
        }
        if let target = try? context.fetch(FetchDescriptor<CachedTarget>(predicate: #Predicate { $0.id == targetId })) {
            for row in target { context.delete(row) }
        }
        save()
    }

    private func save() {
        try? context.save()
    }
}
