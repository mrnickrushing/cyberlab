import SwiftUI

// MARK: - XP Events

enum XPEvent: String, Codable {
    case scanCompleted
    case findingTriaged
    case criticalFinding
    case reportExported
    case targetAdded

    var xp: Int {
        switch self {
        case .scanCompleted:   return 10
        case .findingTriaged:  return 5
        case .criticalFinding: return 15
        case .reportExported:  return 20
        case .targetAdded:     return 5
        }
    }

    var label: String {
        switch self {
        case .scanCompleted:   return "Scan completed"
        case .findingTriaged:  return "Finding triaged"
        case .criticalFinding: return "Critical finding discovered"
        case .reportExported:  return "Report exported"
        case .targetAdded:     return "New target added"
        }
    }

    var icon: String {
        switch self {
        case .scanCompleted:   return "scanner"
        case .findingTriaged:  return "checkmark.shield"
        case .criticalFinding: return "exclamationmark.triangle.fill"
        case .reportExported:  return "doc.text.fill"
        case .targetAdded:     return "target"
        }
    }
}

// MARK: - Ranks

enum OperatorRank: Int, CaseIterable {
    case recruit, analyst, operator_, seniorOperator, specialist, expert, elite

    var title: String {
        switch self {
        case .recruit:        return "Recruit"
        case .analyst:        return "Analyst"
        case .operator_:      return "Operator"
        case .seniorOperator: return "Senior Operator"
        case .specialist:     return "Specialist"
        case .expert:         return "Expert"
        case .elite:          return "Elite"
        }
    }

    /// XP threshold to reach this rank.
    var threshold: Int {
        switch self {
        case .recruit:        return 0
        case .analyst:        return 100
        case .operator_:      return 300
        case .seniorOperator: return 600
        case .specialist:     return 1000
        case .expert:         return 2000
        case .elite:          return 5000
        }
    }

    var icon: String {
        switch self {
        case .recruit:        return "person.fill"
        case .analyst:        return "person.text.rectangle.fill"
        case .operator_:      return "shield.fill"
        case .seniorOperator: return "shield.lefthalf.filled"
        case .specialist:     return "star.fill"
        case .expert:         return "crown.fill"
        case .elite:          return "bolt.shield.fill"
        }
    }
}

// MARK: - Logged XP event (for the recent-events feed)

struct XPLogEntry: Codable, Identifiable {
    var id = UUID()
    let event: XPEvent
    let xp: Int
    let date: Date
}

// MARK: - Rank Manager

@MainActor
final class RankManager: ObservableObject {
    static let shared = RankManager()

    @AppStorage("operatorXP") private var storedXP = 0
    @AppStorage("operatorXPLog") private var logRaw = ""

    @Published var totalXP = 0
    @Published var recentEvents: [XPLogEntry] = []

    private init() {
        totalXP = storedXP
        recentEvents = decodeLog()
    }

    func awardXP(for event: XPEvent) {
        storedXP += event.xp
        totalXP = storedXP
        var log = recentEvents
        log.insert(XPLogEntry(event: event, xp: event.xp, date: Date()), at: 0)
        log = Array(log.prefix(10))
        recentEvents = log
        if let data = try? JSONEncoder().encode(log) {
            logRaw = String(data: data, encoding: .utf8) ?? ""
        }
    }

    private func decodeLog() -> [XPLogEntry] {
        guard let data = logRaw.data(using: .utf8),
              let log = try? JSONDecoder().decode([XPLogEntry].self, from: data) else {
            return []
        }
        return log
    }

    var currentRank: OperatorRank {
        OperatorRank.allCases.last { totalXP >= $0.threshold } ?? .recruit
    }

    var nextRank: OperatorRank? {
        OperatorRank.allCases.first { $0.threshold > totalXP }
    }

    /// Progress (0.0–1.0) from the current rank's threshold to the next rank's.
    var progressToNextRank: Double {
        guard let next = nextRank else { return 1.0 }
        let floor = currentRank.threshold
        let span = next.threshold - floor
        guard span > 0 else { return 1.0 }
        return min(1.0, Double(totalXP - floor) / Double(span))
    }

    var xpToNextRank: Int {
        guard let next = nextRank else { return 0 }
        return max(0, next.threshold - totalXP)
    }
}
