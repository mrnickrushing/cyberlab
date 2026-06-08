import SwiftUI
import Network

// MARK: - Network Monitor
//
// Tracks raw link connectivity via NWPathMonitor and, separately, whether the
// CyberLab API is actually reachable (a device can be on Wi-Fi but unable to
// reach the backend). Views observe `isConnected` to decide between live and
// cached data.

@MainActor
final class NetworkMonitor: ObservableObject {
    @Published var isConnected: Bool = true
    @Published var isAPIReachable: Bool = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.cyberlabmobile.networkmonitor")
    private var reachabilityTask: Task<Void, Never>?

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor in
                guard let self else { return }
                let wasConnected = self.isConnected
                self.isConnected = connected
                if connected {
                    await self.checkAPIReachability()
                } else {
                    self.isAPIReachable = false
                }
                // On a fresh connection, re-verify the API.
                if connected && !wasConnected {
                    await self.checkAPIReachability()
                }
            }
        }
        monitor.start(queue: queue)
        reachabilityTask = Task { await self.checkAPIReachability() }
    }

    deinit {
        monitor.cancel()
        reachabilityTask?.cancel()
    }

    /// Lightweight reachability probe against the API health endpoint with a 3s timeout.
    func checkAPIReachability() async {
        guard let url = URL(string: "\(APIClient.shared.baseURL)/healthz") else {
            isAPIReachable = false
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 3

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 3
        config.timeoutIntervalForResource = 3
        let session = URLSession(configuration: config)

        do {
            let (_, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse {
                isAPIReachable = (200...499).contains(http.statusCode)
            } else {
                isAPIReachable = false
            }
        } catch {
            isAPIReachable = false
        }
    }
}

// MARK: - Offline Banner
//
// Amber warning bar pinned to the top of the screen while offline, signalling
// that the data on display is served from the local cache.

struct OfflineBanner: View {
    @State private var pulsing = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 12, weight: .bold))
            Text("OFFLINE MODE — Showing cached data")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .kerning(0.3)
        }
        .foregroundColor(.black)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.severityMedium)
        .shadow(color: Color.severityMedium.opacity(pulsing ? 0.9 : 0.35), radius: pulsing ? 9 : 3)
        .overlay(
            Rectangle()
                .fill(Color.severityHigh.opacity(0.6))
                .frame(height: 1),
            alignment: .bottom
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
