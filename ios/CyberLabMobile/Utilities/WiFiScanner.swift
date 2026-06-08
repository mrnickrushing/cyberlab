import Foundation
import SystemConfiguration.CaptiveNetwork
import NetworkExtension

// MARK: - WiFi Network Info

struct WiFiNetworkInfo: Identifiable, Equatable {
    let id = UUID()
    var ssid: String
    var bssid: String?
    var signalStrength: Int?      // RSSI in dBm if available, else nil
    var securityType: String      // heuristic label (WPA2 / WPA3 / Open)
    var isConnected: Bool
}

// MARK: - WiFi Scanner
//
// Reads the *current* connected network. A full nearby-network scan on iOS
// requires the `com.apple.developer.networking.HotspotHelper` (NEHotspotHelper)
// entitlement, which Apple grants only by special request and which would break
// signing on a standard provisioning profile — so we do NOT add it to the
// .entitlements file. `CNCopyCurrentNetworkInfo` requires the "Access WiFi
// Information" capability in the provisioning profile; if absent it simply
// returns nil and we surface a graceful message rather than crashing.

@MainActor
final class WiFiScanner: ObservableObject {
    @Published var current: WiFiNetworkInfo?
    @Published var isScanning = false
    @Published var errorMessage: String?
    @Published var lastScan: Date?

    /// Refreshes the currently connected WiFi network details.
    func refresh() {
        isScanning = true
        errorMessage = nil

        Task {
            let info = await Self.fetchCurrentNetwork()
            await MainActor.run {
                self.current = info
                self.lastScan = Date()
                self.isScanning = false
                if info == nil {
                    self.errorMessage = "No WiFi network detected. Connect to WiFi, or the 'Access WiFi Information' capability may be unavailable in this build."
                }
            }
        }
    }

    /// Attempts the modern NEHotspotNetwork API first (iOS 14+), falling back to
    /// the legacy CNCopyCurrentNetworkInfo SystemConfiguration path.
    static func fetchCurrentNetwork() async -> WiFiNetworkInfo? {
        if let hotspot = await fetchViaHotspot() {
            return hotspot
        }
        return fetchViaCaptiveNetwork()
    }

    private static func fetchViaHotspot() async -> WiFiNetworkInfo? {
        await withCheckedContinuation { continuation in
            NEHotspotNetwork.fetchCurrent { network in
                guard let network else {
                    continuation.resume(returning: nil)
                    return
                }
                // signalStrength is 0.0–1.0; convert to an approximate dBm scale.
                let approxRSSI = Int(-100 + (network.signalStrength * 70))
                let info = WiFiNetworkInfo(
                    ssid: network.ssid,
                    bssid: network.bssid,
                    signalStrength: approxRSSI,
                    securityType: securityHeuristic(secure: network.isSecure),
                    isConnected: true
                )
                continuation.resume(returning: info)
            }
        }
    }

    private static func fetchViaCaptiveNetwork() -> WiFiNetworkInfo? {
        guard let interfaces = CNCopySupportedInterfaces() as? [String] else { return nil }
        for interface in interfaces {
            guard
                let dict = CNCopyCurrentNetworkInfo(interface as CFString) as? [String: Any],
                let ssid = dict[kCNNetworkInfoKeySSID as String] as? String
            else { continue }
            let bssid = dict[kCNNetworkInfoKeyBSSID as String] as? String
            return WiFiNetworkInfo(
                ssid: ssid,
                bssid: bssid,
                signalStrength: nil,
                securityType: securityHeuristic(secure: true),
                isConnected: true
            )
        }
        return nil
    }

    /// iOS does not expose the exact security protocol of the joined network via
    /// public API. We use a coarse heuristic: modern devices default to WPA3 on
    /// capable networks, so label secured networks as "WPA2/WPA3".
    private static func securityHeuristic(secure: Bool) -> String {
        guard secure else { return "Open" }
        if #available(iOS 16.0, *) {
            return "WPA2/WPA3"
        }
        return "WPA2"
    }
}
