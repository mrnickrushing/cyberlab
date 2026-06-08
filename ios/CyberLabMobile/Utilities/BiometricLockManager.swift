import SwiftUI
import LocalAuthentication

/// Per-section Face ID / Touch ID gate, layered on top of the app-level unlock.
///
/// Persists a master enable flag plus the set of section keys that require a
/// fresh biometric check before their content is revealed (e.g. "osint",
/// "reports"). Authentications are not cached — each gated entry re-prompts.
@MainActor
final class BiometricLockManager: ObservableObject {
    static let shared = BiometricLockManager()

    @AppStorage("biometricLockEnabled") var isEnabled = false
    /// Comma-separated section keys, stored as a single AppStorage string.
    @AppStorage("biometricLockSections") private var sectionsRaw = ""

    static let allSections: [(key: String, label: String)] = [
        ("osint", "OSINT Results"),
        ("reports", "Report Export"),
    ]

    private init() {}

    var lockedSections: Set<String> {
        Set(sectionsRaw.split(separator: ",").map(String.init))
    }

    func isLocked(_ section: String) -> Bool {
        isEnabled && lockedSections.contains(section)
    }

    func toggleSection(_ section: String, on: Bool) {
        var current = lockedSections
        if on { current.insert(section) } else { current.remove(section) }
        sectionsRaw = current.sorted().joined(separator: ",")
    }

    func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No biometrics/passcode available — fail closed only if a lock was requested.
            return false
        }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }
}

// MARK: - Gate wrapper view

/// Wraps gated content behind a biometric lock screen. When the named section
/// isn't locked, content shows immediately; otherwise the user must authenticate.
struct BiometricGateView<Content: View>: View {
    let section: String
    let label: String
    @ViewBuilder let content: () -> Content

    @StateObject private var lock = BiometricLockManager.shared
    @State private var unlocked = false
    @State private var failed = false
    @State private var authenticating = false

    var body: some View {
        Group {
            if unlocked || !lock.isLocked(section) {
                content()
            } else {
                lockScreen
            }
        }
        .task {
            if lock.isLocked(section) { await tryUnlock() }
        }
    }

    private var lockScreen: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundColor(.cyberGreen)
                .neonGlow(.cyberGreen, radius: 8)
            Text(label)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Text("Authentication required to view this section")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
            if failed {
                Label("Authentication failed", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.severityHigh)
            }
            Button {
                Task { await tryUnlock() }
            } label: {
                Text(authenticating ? "Authenticating…" : "Authenticate")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Color.cyberGreen)
                    .cornerRadius(10)
                    .neonGlow(.cyberGreen, radius: 5)
            }
            .disabled(authenticating)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cyberBackground)
    }

    private func tryUnlock() async {
        authenticating = true
        defer { authenticating = false }
        let ok = await lock.authenticate(reason: "Unlock \(label)")
        if ok {
            withAnimation { unlocked = true; failed = false }
        } else {
            failed = true
        }
    }
}
