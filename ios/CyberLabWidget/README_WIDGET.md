# CyberLab Widget Extension

This directory contains the WidgetKit extension for CyberLab Mobile. **These
files are not yet wired into an Xcode target** — adding a full app-extension
target to `project.pbxproj` by hand is error-prone (it needs a new
`PBXNativeTarget`, build phases, build configurations, a product reference, and
an embed-app-extensions phase in the main app). To avoid corrupting the project
file, the widget target must be added manually in Xcode (or via a project
generator such as Codemagic's Xcode setup).

## Files

| File | Purpose |
|------|---------|
| `CyberLabWidget.swift` | `TimelineProvider`, `TimelineEntry`, design-system colors, and a **duplicated** copy of `WidgetSnapshot` / `WidgetFinding` / `WidgetDataBridge` (the extension can't import the main app). |
| `CyberLabWidgetViews.swift` | SwiftUI views for the small, medium, and lock-screen (`accessoryCircular`) families. |
| `CyberLabWidgetBundle.swift` | `@main WidgetBundle` plus the three `Widget` configurations. |
| `CyberLabWidget.entitlements` | App Group entitlement (`group.com.cyberlabmobile.app`) so the widget can read shared `UserDefaults`. |

## Adding the target in Xcode

1. **File ▸ New ▸ Target… ▸ Widget Extension.** Name it `CyberLabWidget`.
   Uncheck "Include Configuration App Intent" (these widgets are static).
2. Delete the boilerplate Swift file Xcode generates and **add the four files
   in this directory** to the new target instead.
3. Set the extension's **App Groups** capability to
   `group.com.cyberlabmobile.app` (use `CyberLabWidget.entitlements`).
4. Confirm the main app target also has the **App Groups** capability with the
   same group (`CyberLabMobile.entitlements`).
5. Set the extension's deployment target to **iOS 17.0** to match the app.
6. Build & run the main app once so it writes a `WidgetSnapshot`, then add the
   widget from the home screen / lock screen gallery.

## Keeping the bridge in sync

The bridge structs are duplicated between:

- `ios/CyberLabMobile/Utilities/WidgetDataBridge.swift` (main app — writer)
- `ios/CyberLabWidget/CyberLabWidget.swift` (widget — reader)

If you change `WidgetSnapshot` or `WidgetFinding`, update **both** copies. The
suite name (`group.com.cyberlabmobile.app`) and key
(`cyberlab.widget.snapshot`) must also stay identical.

## Refresh triggers

The main app calls `WidgetCenter.shared.reloadAllTimelines()` from:

- `DashboardView` after dashboard stats load (also writes the snapshot).
- `ScansView` when a scan first transitions to `.completed`.
- The notification handlers in `CyberLabMobileApp` (scan-completion pushes).

The timeline policy also refreshes every 15 minutes as a fallback.
