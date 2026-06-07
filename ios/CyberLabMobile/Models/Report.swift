import Foundation

struct ReportSummary: Codable, Identifiable {
    var id: String { targetId }
    let targetId: String
    let targetName: String
    let targetAddress: String
    let targetType: String
    let riskScore: Int
    let riskLabel: String
    let totalFindings: Int
    let bySeverity: SeverityBreakdown
    let totalScans: Int
    let generatedAt: String
}

struct SeverityBreakdown: Codable {
    let critical: Int
    let high: Int
    let medium: Int
    let low: Int
    let info: Int
}

struct FullReport: Codable {
    let generatedAt: String
    let target: ReportTarget
    let riskScore: Int
    let riskLabel: String
    let summary: ReportSummary2
    let findings: [ReportFinding]
    let scans: [ReportScan]
    let remediations: [ReportRemediation]
}

struct ReportTarget: Codable {
    let id: String
    let name: String
    let address: String
    let type: String
    let authorizationStatus: String
    let riskLevel: String
    let owner: String?
}

struct ReportSummary2: Codable {
    let totalFindings: Int
    let openFindings: Int
    let bySeverity: SeverityBreakdown
    let totalScans: Int
    let toolsUsed: [String]
}

struct ReportFinding: Codable, Identifiable {
    let id: String
    let title: String
    let severity: String
    let status: String
    let cveId: String?
    let cvssScore: Double?
    let description: String?
    let remediation: String?
    let createdAt: String

    var severityEnum: FindingSeverity {
        FindingSeverity(rawValue: severity) ?? .info
    }
}

struct ReportScan: Codable, Identifiable {
    let id: String
    let tool: String
    let status: String
    let createdAt: String
    let completedAt: String?
}

struct ReportRemediation: Codable, Identifiable {
    var id: String { title }
    let title: String
    let severity: String
    let remediation: String?
}

extension ReportSummary {
    var riskColor: Color {
        switch riskScore {
        case 80...100: return .cyberGreen
        case 60..<80:  return .yellow
        case 40..<60:  return .orange
        default:       return .red
        }
    }
}

extension FullReport {
    var riskColor: Color {
        switch riskScore {
        case 80...100: return .cyberGreen
        case 60..<80:  return .yellow
        case 40..<60:  return .orange
        default:       return .red
        }
    }
}

import SwiftUI
