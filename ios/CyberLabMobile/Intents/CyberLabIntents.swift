import AppIntents

// Intent 1: Get Risk Score
struct GetRiskScoreIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Risk Score"
    static var description = IntentDescription("Get the current risk score for a target in CyberLab")

    @Parameter(title: "Target Name") var targetName: String

    func perform() async throws -> some ReturnsValue<Int> & ProvidesDialog {
        let snapshot = WidgetDataBridge.shared.read()
        let score = snapshot?.riskScore ?? 0
        return .result(value: score, dialog: "The risk score for \(targetName) is \(score) out of 100.")
    }
}

// Intent 2: List Open Findings
struct ListOpenFindingsIntent: AppIntent {
    static var title: LocalizedStringResource = "List Open Findings"
    static var description = IntentDescription("List the top open security findings in CyberLab")

    func perform() async throws -> some ReturnsValue<String> & ProvidesDialog {
        let snapshot = WidgetDataBridge.shared.read()
        let findings = snapshot?.topFindings ?? []
        if findings.isEmpty {
            return .result(value: "No open findings", dialog: "No open findings found in CyberLab.")
        }
        let list = findings.map { "• \($0.title) (\($0.severity))" }.joined(separator: "\n")
        return .result(value: list, dialog: "Here are your top open findings in CyberLab: \(findings.map(\.title).joined(separator: ", "))")
    }
}

// Intent 3: Run Scan (opens app to new scan sheet)
struct RunScanIntent: AppIntent {
    static var title: LocalizedStringResource = "Run Scan"
    static var description = IntentDescription("Open CyberLab and start a new scan")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

// Shortcuts provider
struct CyberLabShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetRiskScoreIntent(),
            phrases: [
                "Get risk score in \(.applicationName)",
                "Check \(.applicationName) security score"
            ]
        )
        AppShortcut(
            intent: ListOpenFindingsIntent(),
            phrases: [
                "List findings in \(.applicationName)",
                "Show \(.applicationName) vulnerabilities"
            ]
        )
        AppShortcut(
            intent: RunScanIntent(),
            phrases: [
                "Run a scan in \(.applicationName)",
                "Start \(.applicationName) scan"
            ]
        )
    }
}
