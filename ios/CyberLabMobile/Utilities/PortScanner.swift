import Foundation
import Network

// MARK: - Port Result

enum PortState: String {
    case open = "OPEN"
    case closed = "CLOSED"
    case filtered = "FILTERED"
}

struct PortResult: Identifiable, Equatable {
    let id = UUID()
    let port: UInt16
    let service: String
    var state: PortState
}

// MARK: - Port Presets

struct PortPreset: Identifiable {
    let id: String
    let label: String
    let ports: [UInt16]
}

enum PortPresets {
    static let top20 = PortPreset(
        id: "top20", label: "Top 20 Ports",
        ports: [21, 22, 23, 25, 53, 80, 110, 135, 139, 143, 443, 445, 993, 995, 1723, 3306, 3389, 5900, 8080, 8443]
    )
    static let web = PortPreset(
        id: "web", label: "Web Ports",
        ports: [80, 443, 8080, 8443, 8000, 8888, 3000, 5000, 9000]
    )
    static let database = PortPreset(
        id: "database", label: "Database Ports",
        ports: [1433, 1521, 3306, 5432, 6379, 9042, 27017, 11211, 5984]
    )
    static let all: [PortPreset] = [top20, web, database]

    /// Common service names keyed by port for result labelling.
    static let serviceNames: [UInt16: String] = [
        21: "ftp", 22: "ssh", 23: "telnet", 25: "smtp", 53: "dns",
        80: "http", 110: "pop3", 135: "msrpc", 139: "netbios", 143: "imap",
        443: "https", 445: "smb", 993: "imaps", 995: "pop3s", 1433: "mssql",
        1521: "oracle", 1723: "pptp", 3000: "node", 3306: "mysql", 3389: "rdp",
        5000: "upnp", 5432: "postgres", 5900: "vnc", 5984: "couchdb", 6379: "redis",
        8000: "http-alt", 8080: "http-proxy", 8443: "https-alt", 8888: "http-alt",
        9000: "http-alt", 9042: "cassandra", 11211: "memcached", 27017: "mongodb",
    ]

    static func service(for port: UInt16) -> String {
        serviceNames[port] ?? "unknown"
    }
}

// MARK: - Port Scanner
//
// Performs TCP-connect scanning of a target host across a set of ports using
// the Network framework. A successful connection within the timeout = OPEN;
// an explicit failure = CLOSED; a timeout with no response = FILTERED.

@MainActor
final class PortScanner: ObservableObject {
    @Published var results: [PortResult] = []
    @Published var isScanning = false
    @Published var progress: Double = 0
    @Published var target: String = ""
    @Published var errorMessage: String?

    private let maxConcurrent = 16
    private let timeoutSeconds: Double = 1.0
    private var scanTask: Task<Void, Never>?

    func start(host: String, ports: [UInt16]) {
        let trimmed = host.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            errorMessage = "Enter a target host or IP"
            return
        }
        guard !isScanning else { return }

        target = trimmed
        errorMessage = nil
        results = []
        progress = 0
        isScanning = true

        scanTask = Task { await scan(host: trimmed, ports: ports) }
    }

    func stop() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
    }

    private func scan(host: String, ports: [UInt16]) async {
        let total = ports.count
        let timeout = timeoutSeconds
        var completed = 0

        await withTaskGroup(of: PortResult.self) { group in
            var index = 0

            func enqueue() {
                guard index < ports.count else { return }
                let port = ports[index]
                index += 1
                group.addTask {
                    await Self.probe(host: host, port: port, timeout: timeout)
                }
            }

            while index < min(maxConcurrent, ports.count) { enqueue() }

            for await result in group {
                if Task.isCancelled { break }
                completed += 1
                progress = Double(completed) / Double(total)
                results.append(result)
                results.sort { $0.port < $1.port }
                enqueue()
            }
        }

        isScanning = false
        progress = 1
    }

    static func probe(host: String, port: UInt16, timeout: Double) async -> PortResult {
        let service = PortPresets.service(for: port)
        let state: PortState = await withCheckedContinuation { continuation in
            let endpoint = NWEndpoint.Host(host)
            guard let nwPort = NWEndpoint.Port(rawValue: port) else {
                continuation.resume(returning: .closed)
                return
            }
            let connection = NWConnection(host: endpoint, port: nwPort, using: .tcp)
            let finished = ManagedAtomicFlag()
            let queue = DispatchQueue(label: "port.probe.\(host).\(port)")

            func finish(_ result: PortState) {
                guard finished.testAndSet() else { return }
                connection.cancel()
                continuation.resume(returning: result)
            }

            connection.stateUpdateHandler = { newState in
                switch newState {
                case .ready:
                    finish(.open)
                case .failed:
                    finish(.closed)
                case .cancelled:
                    break
                default:
                    break
                }
            }

            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) {
                // No definitive response within the window — port is filtered.
                finish(.filtered)
            }
        }
        return PortResult(port: port, service: service, state: state)
    }
}
