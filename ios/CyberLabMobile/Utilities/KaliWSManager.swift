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
    private let url = URL(string: "wss://terminal.vitallity.org")!
    private var isConnected: Bool { state == .connected }

    private init() {}

    func connect() {
        guard state == .disconnected else { return }
        state = .connecting
        openSocket()
    }

    func disconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        state = .disconnected
    }

    func reconnect() {
        disconnect()
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            connect()
        }
    }

    private func openSocket() {
        let session = URLSession(configuration: .default)
        let ws = session.webSocketTask(with: url)
        task = ws
        ws.resume()

        // Register as phone client
        if let data = try? JSONSerialization.data(withJSONObject: ["type": "register", "clientType": "phone"]) {
            ws.send(.data(data)) { _ in }
        }

        state = .connected
        receive(ws)
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
                case .failure:
                    // Socket closed — relay dropped us (Kali not connected or timeout)
                    // Don't auto-reconnect in a loop — wait for user to tap Reconnect
                    self.state = .disconnected
                    self.task = nil
                }
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }
        if type == "output", let out = json["data"] as? String {
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
