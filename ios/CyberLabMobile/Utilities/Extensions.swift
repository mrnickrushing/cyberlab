import SwiftUI

// MARK: - Color Extensions

extension Color {
    static let cyberGreen = Color(red: 0.063, green: 0.725, blue: 0.506)
    static let cyberBackground = Color(red: 0.047, green: 0.063, blue: 0.082)
    static let cyberSurface = Color(red: 0.071, green: 0.098, blue: 0.133)
    static let cyberBorder = Color(red: 0.137, green: 0.188, blue: 0.251)
}

extension FindingSeverity {
    var color: Color {
        switch self {
        case .critical: return Color(red: 0.9, green: 0.1, blue: 0.1)
        case .high: return Color(red: 0.95, green: 0.5, blue: 0.1)
        case .medium: return Color(red: 0.95, green: 0.8, blue: 0.1)
        case .low: return Color(red: 0.2, green: 0.6, blue: 0.95)
        case .info: return Color(red: 0.5, green: 0.5, blue: 0.6)
        }
    }

    var label: String { rawValue.capitalized }
}

extension FindingStatus {
    var label: String {
        switch self {
        case .open: return "Open"
        case .fixed: return "Fixed"
        case .acceptedRisk: return "Accepted Risk"
        case .falsePositive: return "False Positive"
        }
    }
    var color: Color {
        switch self {
        case .open: return .red
        case .fixed: return .green
        case .acceptedRisk: return .orange
        case .falsePositive: return .gray
        }
    }
}

extension ScanStatus {
    var label: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .pending: return .gray
        case .running: return .cyberGreen
        case .completed: return .blue
        case .failed: return .red
        case .cancelled: return .orange
        }
    }
    var isActive: Bool { self == .pending || self == .running }
}

extension AuthorizationStatus {
    var label: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .authorized: return .cyberGreen
        case .unauthorized: return .red
        case .pending: return .orange
        }
    }
}

extension RiskLevel {
    var label: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .critical: return Color(red: 0.9, green: 0.1, blue: 0.1)
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        case .info: return .gray
        }
    }
}

extension TargetType {
    var label: String {
        switch self {
        case .ip: return "IP"
        case .domain: return "Domain"
        case .subnet: return "Subnet"
        case .webapp: return "Web App"
        }
    }
    var systemImage: String {
        switch self {
        case .ip: return "server.rack"
        case .domain: return "globe"
        case .subnet: return "network"
        case .webapp: return "safari"
        }
    }
}

// MARK: - Date Formatting

extension String {
    var formattedDate: String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: self) {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: date, relativeTo: Date())
        }
        return self
    }

    var formattedFullDate: String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: self) {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        return self
    }
}

// MARK: - View Modifiers

struct CyberCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.cyberSurface)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.cyberBorder, lineWidth: 1)
            )
    }
}

extension View {
    func cyberCard() -> some View {
        modifier(CyberCardModifier())
    }
}

// MARK: - Badge View

struct SeverityBadge: View {
    let severity: FindingSeverity
    var body: some View {
        Text(severity.label)
            .font(.caption2.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(severity.color)
            .cornerRadius(4)
    }
}

struct StatusBadge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color)
            .cornerRadius(4)
    }
}
