import Foundation
import SystemConfiguration
import CFNetwork

// MARK: - Network Status Snapshot

struct NetworkStatus: Equatable {
    var vpnActive: Bool
    var proxyDetected: Bool
    var proxyHost: String?
    var torLikely: Bool
    var checkedTor: Bool       // whether the Tor probe completed
}

// MARK: - VPN / Proxy / Tor Detector
//
// VPN: iOS routes VPN traffic through "utun"/"ipsec"/"tap"/"ppp" interfaces.
//      Enumerating CFNetworkCopySystemProxySettings → __SCOPED__ keys reveals
//      these tunnel interfaces when a VPN is active.
// Proxy: CFNetworkCopySystemProxySettings exposes any configured HTTP proxy.
// Tor:  We query the canonical check.torproject.org endpoint; if our exit
//       appears to be a Tor node it reports IsTor=true.

@MainActor
final class VPNDetector: ObservableObject {
    @Published var status = NetworkStatus(vpnActive: false, proxyDetected: false, proxyHost: nil, torLikely: false, checkedTor: false)
    @Published var isChecking = false

    func refresh(checkTor: Bool = true) {
        isChecking = true
        let vpn = Self.isVPNActive()
        let (proxy, host) = Self.proxyInfo()

        status = NetworkStatus(vpnActive: vpn, proxyDetected: proxy, proxyHost: host, torLikely: false, checkedTor: false)

        guard checkTor else {
            isChecking = false
            return
        }

        Task {
            let tor = await Self.checkTor()
            await MainActor.run {
                self.status.torLikely = tor
                self.status.checkedTor = true
                self.isChecking = false
            }
        }
    }

    // MARK: - VPN interface detection

    static func isVPNActive() -> Bool {
        guard
            let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any],
            let scoped = settings["__SCOPED__"] as? [String: Any]
        else { return false }

        let tunnelPrefixes = ["tap", "tun", "utun", "ppp", "ipsec"]
        for key in scoped.keys {
            if tunnelPrefixes.contains(where: { key.hasPrefix($0) }) {
                return true
            }
        }
        return false
    }

    // MARK: - Proxy detection

    static func proxyInfo() -> (detected: Bool, host: String?) {
        guard let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any] else {
            return (false, nil)
        }
        let httpEnabled = (settings[kCFNetworkProxiesHTTPEnable as String] as? Int) == 1
        let httpsEnabled = (settings["HTTPSEnable"] as? Int) == 1
        let host = settings[kCFNetworkProxiesHTTPProxy as String] as? String
            ?? settings["HTTPSProxy"] as? String
        let detected = httpEnabled || httpsEnabled || (host != nil)
        return (detected, host)
    }

    // MARK: - Tor detection

    static func checkTor() async -> Bool {
        guard let url = URL(string: "https://check.torproject.org/api/ip") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 4
        request.cachePolicy = .reloadIgnoringLocalCacheData
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let isTor = json["IsTor"] as? Bool {
                return isTor
            }
        } catch {
            return false
        }
        return false
    }
}
