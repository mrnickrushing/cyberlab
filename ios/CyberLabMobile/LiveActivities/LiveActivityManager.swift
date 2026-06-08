import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

// MARK: - Activity Attributes

#if canImport(ActivityKit)
@available(iOS 16.2, *)
struct ScanActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var tool: String
        var progress: Int
        var statusLabel: String
        var elapsedSeconds: Int
    }

    var targetName: String
}
#endif

/// Manages the lifecycle of a scan Live Activity (lock screen + Dynamic Island).
///
/// The actual ActivityKit extension target requires Mac/Xcode provisioning that
/// isn't available in this environment, so every ActivityKit call is gated behind
/// `#available` + `#canImport`. When ActivityKit is present the manager starts a
/// real Live Activity; otherwise it no-ops gracefully. The infrastructure is fully
/// wired so the extension can be added from a Mac later without touching call sites.
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var startDate = Date()

    #if canImport(ActivityKit)
    @available(iOS 16.2, *)
    private var currentActivity: Activity<ScanActivityAttributes>? {
        get { _currentActivity as? Activity<ScanActivityAttributes> }
        set { _currentActivity = newValue }
    }
    private var _currentActivity: Any?
    #endif

    private init() {}

    func startScanActivity(targetName: String) {
        startDate = Date()
        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = ScanActivityAttributes(targetName: targetName)
        let initial = ScanActivityAttributes.ContentState(
            tool: "queued", progress: 0, statusLabel: "Starting", elapsedSeconds: 0
        )
        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                contentState: initial,
                pushType: nil
            )
        } catch {
            // Activities not available / disabled — no-op.
        }
        #endif
    }

    func updateScanActivity(tool: String, progress: Int) {
        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *), let activity = currentActivity else { return }
        let state = ScanActivityAttributes.ContentState(
            tool: tool,
            progress: progress,
            statusLabel: progress >= 100 ? "Finishing" : "Running",
            elapsedSeconds: Int(Date().timeIntervalSince(startDate))
        )
        Task { await activity.update(using: state) }
        #endif
    }

    func endScanActivity(didFindCriticals: Bool) {
        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *), let activity = currentActivity else { return }
        let finalState = ScanActivityAttributes.ContentState(
            tool: "done",
            progress: 100,
            statusLabel: didFindCriticals ? "Critical findings" : "Completed",
            elapsedSeconds: Int(Date().timeIntervalSince(startDate))
        )
        Task {
            await activity.end(using: finalState, dismissalPolicy: .default)
        }
        currentActivity = nil
        #endif
    }
}
