import SwiftUI

// MARK: - CVSS v3.1 Base Score Calculator
//
// Implements the FIRST CVSS v3.1 base metric specification. Each metric maps to
// a numeric coefficient; the score is derived from the Impact and Exploitability
// subscores per the official formula.

// Generic metric option: a label, its vector abbreviation, and numeric weight.
struct CVSSOption: Hashable {
    let label: String
    let abbrev: String
    let value: Double
}

enum CVSSMetric: String, CaseIterable, Identifiable {
    case attackVector = "Attack Vector"
    case attackComplexity = "Attack Complexity"
    case privilegesRequired = "Privileges Required"
    case userInteraction = "User Interaction"
    case scope = "Scope"
    case confidentiality = "Confidentiality"
    case integrity = "Integrity"
    case availability = "Availability"

    var id: String { rawValue }

    var vectorKey: String {
        switch self {
        case .attackVector: return "AV"
        case .attackComplexity: return "AC"
        case .privilegesRequired: return "PR"
        case .userInteraction: return "UI"
        case .scope: return "S"
        case .confidentiality: return "C"
        case .integrity: return "I"
        case .availability: return "A"
        }
    }

    var options: [CVSSOption] {
        switch self {
        case .attackVector:
            return [
                CVSSOption(label: "Network", abbrev: "N", value: 0.85),
                CVSSOption(label: "Adjacent", abbrev: "A", value: 0.62),
                CVSSOption(label: "Local", abbrev: "L", value: 0.55),
                CVSSOption(label: "Physical", abbrev: "P", value: 0.2),
            ]
        case .attackComplexity:
            return [
                CVSSOption(label: "Low", abbrev: "L", value: 0.77),
                CVSSOption(label: "High", abbrev: "H", value: 0.44),
            ]
        case .privilegesRequired:
            // Values depend on Scope; the score function adjusts for Changed scope.
            return [
                CVSSOption(label: "None", abbrev: "N", value: 0.85),
                CVSSOption(label: "Low", abbrev: "L", value: 0.62),
                CVSSOption(label: "High", abbrev: "H", value: 0.27),
            ]
        case .userInteraction:
            return [
                CVSSOption(label: "None", abbrev: "N", value: 0.85),
                CVSSOption(label: "Required", abbrev: "R", value: 0.62),
            ]
        case .scope:
            return [
                CVSSOption(label: "Unchanged", abbrev: "U", value: 0),
                CVSSOption(label: "Changed", abbrev: "C", value: 1),
            ]
        case .confidentiality, .integrity, .availability:
            return [
                CVSSOption(label: "None", abbrev: "N", value: 0),
                CVSSOption(label: "Low", abbrev: "L", value: 0.22),
                CVSSOption(label: "High", abbrev: "H", value: 0.56),
            ]
        }
    }
}

@MainActor
final class CVSSCalculator: ObservableObject {
    // Default to the highest-severity selection (matches NVD calculator default).
    @Published var selections: [CVSSMetric: CVSSOption]

    init() {
        var defaults: [CVSSMetric: CVSSOption] = [:]
        for metric in CVSSMetric.allCases {
            defaults[metric] = metric.options.first
        }
        selections = defaults
    }

    private func option(_ metric: CVSSMetric) -> CVSSOption {
        selections[metric] ?? metric.options[0]
    }

    var isScopeChanged: Bool {
        option(.scope).abbrev == "C"
    }

    /// Privileges Required is re-weighted when Scope is Changed.
    private var privilegesRequiredValue: Double {
        let pr = option(.privilegesRequired)
        guard isScopeChanged else { return pr.value }
        switch pr.abbrev {
        case "L": return 0.68
        case "H": return 0.5
        default: return pr.value // None unchanged
        }
    }

    var baseScore: Double {
        let confidentiality = option(.confidentiality).value
        let integrity = option(.integrity).value
        let availability = option(.availability).value

        let iscBase = 1 - ((1 - confidentiality) * (1 - integrity) * (1 - availability))

        let impact: Double
        if isScopeChanged {
            impact = 7.52 * (iscBase - 0.029) - 3.25 * pow(iscBase - 0.02, 15)
        } else {
            impact = 6.42 * iscBase
        }

        guard impact > 0 else { return 0 }

        let exploitability = 8.22
            * option(.attackVector).value
            * option(.attackComplexity).value
            * privilegesRequiredValue
            * option(.userInteraction).value

        let raw: Double
        if isScopeChanged {
            raw = min(1.08 * (impact + exploitability), 10)
        } else {
            raw = min(impact + exploitability, 10)
        }
        return roundUp(raw)
    }

    /// CVSS spec "Roundup": smallest number, to one decimal place, >= input.
    private func roundUp(_ value: Double) -> Double {
        let scaled = (value * 100000).rounded()
        if Int(scaled) % 10000 == 0 {
            return scaled / 100000
        }
        return (floor(scaled / 10000) + 1) / 10
    }

    var severityLabel: String {
        let s = baseScore
        if s >= 9.0 { return "CRITICAL" }
        if s >= 7.0 { return "HIGH" }
        if s >= 4.0 { return "MEDIUM" }
        if s >= 0.1 { return "LOW" }
        return "NONE"
    }

    var severityColor: Color {
        let s = baseScore
        if s >= 9.0 { return .severityCritical }
        if s >= 7.0 { return .severityHigh }
        if s >= 4.0 { return .severityMedium }
        if s >= 0.1 { return .severityLow }
        return .severityInfo
    }

    var vectorString: String {
        let parts = CVSSMetric.allCases.map { "\($0.vectorKey):\(option($0).abbrev)" }
        return "CVSS:3.1/" + parts.joined(separator: "/")
    }
}

struct CVSSCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var calc = CVSSCalculator()
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cyberBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        scoreHeader
                        vectorCard
                        ForEach(CVSSMetric.allCases) { metric in
                            metricRow(metric)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("CVSS v3.1")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.cyberGreen)
                }
            }
        }
    }

    // MARK: Score header

    private var scoreHeader: some View {
        VStack(spacing: 6) {
            Text(String(format: "%.1f", calc.baseScore))
                .font(.system(size: 64, weight: .black, design: .monospaced))
                .foregroundColor(calc.severityColor)
                .neonGlow(calc.severityColor, radius: 8)
            Text(calc.severityLabel)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .kerning(2)
                .foregroundColor(calc.severityColor)
            Text("BASE SCORE")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .cyberCard()
        .hudFrame(color: calc.severityColor.opacity(0.5), length: 14)
    }

    // MARK: Vector string + copy

    private var vectorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("VECTOR STRING")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
            Text(calc.vectorString)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.cyberCyan)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                UIPasteboard.general.string = calc.vectorString
                HapticFeedback.success()
                withAnimation { copied = true }
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    withAnimation { copied = false }
                }
            } label: {
                HStack {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    Text(copied ? "Copied" : "Copy Vector")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.cyberGreen)
                .cornerRadius(8)
            }
        }
        .cyberCard()
    }

    // MARK: Metric selector row

    private func metricRow(_ metric: CVSSMetric) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(metric.rawValue.uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
            HStack(spacing: 6) {
                ForEach(metric.options, id: \.self) { option in
                    let isSelected = calc.selections[metric]?.abbrev == option.abbrev
                    Button {
                        HapticFeedback.statusChange()
                        calc.selections[metric] = option
                    } label: {
                        Text(option.label)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(isSelected ? .black : .white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(isSelected ? Color.cyberGreen : Color.cyberSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(isSelected ? Color.cyberGreen : Color.cyberBorder, lineWidth: 1)
                            )
                            .cornerRadius(6)
                    }
                }
            }
        }
        .cyberCard()
    }
}
