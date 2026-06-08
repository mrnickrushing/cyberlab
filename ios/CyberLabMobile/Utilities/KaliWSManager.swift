import Foundation
import Combine

@MainActor
class KaliWSManager: ObservableObject {
    static let shared = KaliWSManager()

    @Published var isConnected = false
    @Published var outputBuffer = ""

    private var task: URLSessionWebSocketTask?
    private var reconnectDelay: TimeInterval = 1
    private var shouldReconnect = true
    private let url = URL(string: "wss://terminal.vitallity.org")!

    private init() {}

    func connect() {
        shouldReconnect = true
        openSocket()
    }

    func disconnect() {
        shouldReconnect = false
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        isConnected = false
    }

    private func openSocket() {
        let session = URLSession(configuration: .default)
        let ws = session.webSocketTask(with: url)
        task = ws
        ws.resume()

        // Register as phone client
        let reg = try? JSONSerialization.data(withJSONObject: ["type": "register", "clientType": "phone"])
        if let reg {
            ws.send(.data(reg)) { _ in }
        }

        isConnected = true
        reconnectDelay = 1
        receive(ws)
    }

    private func receive(_ ws: URLSessionWebSocketTask) {
        ws.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .success(let msg):
                    switch msg {
                    case .string(let text):
                        self.handleMessage(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self.handleMessage(text)
                        }
                    @unknown default: break
                    }
                    self.receive(ws)
                case .failure:
                    self.isConnected = false
                    self.scheduleReconnect()
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
            // Cap buffer at ~50k chars
            if outputBuffer.count > 50_000 {
                outputBuffer = String(outputBuffer.suffix(40_000))
            }
        }
    }

    private func scheduleReconnect() {
        guard shouldReconnect else { return }
        let delay = reconnectDelay
        reconnectDelay = min(reconnectDelay * 2, 30)
        Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await MainActor.run {
                if self.shouldReconnect { self.openSocket() }
            }
        }
    }

    func sendCommand(_ cmd: String) {
        let payload = ["type": "command", "data": cmd + "\n"]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        task?.send(.data(data)) { _ in }
    }

    func sendCtrlC() {
        let payload = ["type": "key", "data": "\u{03}"]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        task?.send(.data(data)) { _ in }
    }

    func clearBuffer() {
        outputBuffer = ""
    }
}
