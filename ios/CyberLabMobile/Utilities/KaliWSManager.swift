import Foundation
import Combine

@MainActor
class KaliWSManager: ObservableObject {
    static let shared = KaliWSManager()

    enum ConnectionState {
        case disconnected
        case connecting
        case connected      // relay up, Kali may or may not be present
    }

    @Published var state: ConnectionState = .disconnected
    @Published var outputBuffer = ""

    private var task: URLSessionWebSocketTask?
    private var reconnectTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private let url = URL(string: "wss://terminal.vitallity.org/ws")!
    private var isConnected: Bool { state == .connected }

    private init() {}

    func connect() {
        guard state == .disconnected else { return }
        state = .connecting
        openSocket()
    }

    func disconnect() {
        cancelAllTasks()
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        state = .disconnected
    }

    func reconnect() {
        cancelAllTasks()
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        state = .disconnected
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            connect()
        }
    }

    private func cancelAllTasks() {
        reconnectTask?.cancel()
        reconnectTask = nil
        pingTask?.cancel()
        pingTask = nil
    }

    private func openSocket() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = .infinity
        let session = URLSession(configuration: config)
        let ws = session.webSocketTask(with: url)
        task = ws
        ws.resume()

        // Register as phone client
        if let data = try? JSONSerialization.data(withJSONObject: ["type": "register", "clientType": "phone"]) {
            ws.send(.data(data)) { _ in }
        }

        state = .connected
        receive(ws)
        schedulePing(ws)
    }

    // Send a ping every 30s to keep the connection alive and detect drops early
    private func schedulePing(_ ws: URLSessionWebSocketTask) {
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    guard let self, self.task === ws, self.state == .connected else { return }
                    ws.sendPing { [weak self] error in
                        Task { @MainActor [weak self] in
                            guard let self, self.task === ws else { return }
                            if let error = error {
                                // Ping failed — socket is dead, reconnect automatically
                                print("[KaliWS] Ping failed: \(error.localizedDescription). Reconnecting...")
                                self.reconnect()
                            }
                        }
                    }
                }
            }
        }
    }

    private func receive(_ ws: URLSessionWebSocketTask) {
        ws.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self, self.task === ws else { return }
                switch result {
                case .success(let msg):
                    switch msg {
                    case .string(let text): self.handleMessage(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) { self.handleMessage(text) }
                    @unknown default: break
                    }
                    self.receive(ws)
                case .failure(let error):
                    // Socket closed or timed out — auto-reconnect
                    print("[KaliWS] Receive error: \(error.localizedDescription). Auto-reconnecting...")
                    self.pingTask?.cancel()
                    self.pingTask = nil
                    self.task = nil
                    self.state = .disconnected
                    // Auto-reconnect after 2 seconds
                    self.reconnectTask = Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        guard !Task.isCancelled else { return }
                        await MainActor.run {
                            guard self.state == .disconnected else { return }
                            self.connect()
                        }
                    }
                }
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }
        if type == "output",
           let out = (json["output"] as? String) ?? (json["data"] as? String) {
            outputBuffer += out.strippingANSI()
            if outputBuffer.count > 50_000 {
                outputBuffer = String(outputBuffer.suffix(40_000))
            }
        }
    }

    func sendCommand(_ cmd: String) {
        guard isConnected else { return }
        let payload = ["type": "command", "data": cmd + "\n"]
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            task?.send(.data(data)) { _ in }
        }
    }

    func sendCtrlC() {
        let payload = ["type": "key", "data": "\u{03}"]
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            task?.send(.data(data)) { _ in }
        }
    }

    func clearBuffer() { outputBuffer = "" }
}
