import Foundation

struct Schedule: Codable, Identifiable {
    let id: String
    let targetId: String
    let targetName: String
    let targetAddress: String
    let tool: String
    let flags: ScheduleFlags
    let cronExpression: String
    let label: String?
    let enabled: Bool
    let lastRunAt: Date?
    let nextRunAt: Date?
    let createdAt: Date

    var displayLabel: String {
        label ?? "\(tool) on \(targetName)"
    }

    var cronDisplayName: String {
        CronPreset.allPresets.first { $0.value == cronExpression }?.label ?? cronExpression
    }
}

struct ScheduleFlags: Codable {
    let flags: String?
}

struct CronPreset: Identifiable {
    let id = UUID()
    let label: String
    let value: String

    static let allPresets: [CronPreset] = [
        CronPreset(label: "Every hour",       value: "0 * * * *"),
        CronPreset(label: "Every 6 hours",    value: "0 */6 * * *"),
        CronPreset(label: "Every 12 hours",   value: "0 */12 * * *"),
        CronPreset(label: "Daily at midnight",value: "0 0 * * *"),
        CronPreset(label: "Every Monday 2am", value: "0 2 * * 1"),
        CronPreset(label: "Every Sunday 3am", value: "0 3 * * 0"),
    ]
}

struct CreateScheduleRequest: Codable {
    let targetId: String
    let tool: String
    let flags: String
    let cronExpression: String
    let label: String?
}

struct UpdateScheduleRequest: Codable {
    let enabled: Bool?
    let cronExpression: String?
    let label: String?

    init(enabled: Bool? = nil, cronExpression: String? = nil, label: String? = nil) {
        self.enabled = enabled
        self.cronExpression = cronExpression
        self.label = label
    }
}

