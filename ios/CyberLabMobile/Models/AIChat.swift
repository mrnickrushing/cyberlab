import Foundation

enum AIMode: String, CaseIterable, Identifiable {
    case general    = "general"
    case explain    = "explain"
    case summarize  = "summarize"
    case remediation = "remediation"
    case study      = "study"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .general:     return "General"
        case .explain:     return "Explain"
        case .summarize:   return "Summarize"
        case .remediation: return "Remediation"
        case .study:       return "Study"
        }
    }

    var icon: String {
        switch self {
        case .general:     return "bubble.left.and.bubble.right.fill"
        case .explain:     return "questionmark.circle.fill"
        case .summarize:   return "doc.text.magnifyingglass"
        case .remediation: return "wrench.and.screwdriver.fill"
        case .study:       return "graduationcap.fill"
        }
    }

    var description: String {
        switch self {
        case .general:     return "Ask anything about security"
        case .explain:     return "Explain a finding"
        case .summarize:   return "Summarize a report"
        case .remediation: return "Get fix recommendations"
        case .study:       return "Learn security concepts"
        }
    }
}

struct AIChatMessage: Identifiable {
    let id = UUID()
    let role: ChatRole
    let content: String
    let timestamp: Date = .now
}

enum ChatRole: String {
    case user, assistant
}

struct AIChatRequest: Codable {
    let message: String
    let mode: String
    let context: AIChatContext?
    let history: [AIChatHistoryTurn]?
}

struct AIChatHistoryTurn: Codable {
    let role: String
    let content: String
}

struct AIChatContext: Codable {
    // Finding context
    var findingTitle: String?
    var findingSeverity: String?
    var findingCveId: String?
    var findingCvssScore: Double?
    var findingDescription: String?
    var findingRemediation: String?
    // Report context
    var reportTargetName: String?
    var reportRiskScore: Int?
    var reportRiskLabel: String?
    var reportOpenFindings: Int?
    var reportBySeverity: SeverityBreakdown?
    var reportToolsUsed: [String]?
    var reportTopFindings: [ReportTopFinding]?
}

struct ReportTopFinding: Codable {
    let title: String
    let severity: String
    let cveId: String?
}

struct AIChatResponse: Codable {
    let reply: String
    let mode: String
    let inputTokens: Int?
    let outputTokens: Int?
}

struct AIStatus: Codable {
    let configured: Bool
}
