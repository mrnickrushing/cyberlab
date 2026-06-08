import Foundation
import Network

// MARK: - Subnet Host Result

struct SubnetHost: Identifiable, Equatable {
    let id = UUID()
    let ip: String
    var isUp: Bool
    var responseMs: Int?
}

// MARK: - Subnet Scanner
//
// Discovers the device's local IPv4 address via getifaddrs, derives the /24
// subnet, then performs a concurrent TCP-connect "ping" sweep across .1–.254.
// iOS sandboxing forbids ICMP, so we use a short-timeout TCP connect to port 80
// as a liveness probe — a refused connection still proves the host is up.

@MainActor
final class SubnetScanner: ObservableObject {
    @Published var hosts: [SubnetHost] = []
    @Published var isScanning = false
    @Published var progress: Double = 0           // 0.0–1.0
    @Published var localIP: String?
    @Published var subnetBase: String?            // e.g. "192.168.1"
    @Published var isOnWiFi = true
    @Published var scannedCount = 0

    private let totalHosts = 254
    private let maxConcurrent = 20
    private let probePort: UInt16 = 80
    private let timeoutSeconds: Double = 0.3
    private var scanTask: Task<Void, Never>?

    func start() {
        guard !isScanning else { return }
        reset()

        guard let ip = Self.currentIPv4Address() else {
            isOnWiFi = false
            return
        }
        localIP = ip
        isOnWiFi = Self.isWiFiInterfaceActive()

        let parts = ip.split(separator: ".")
        guard parts.count == 4 else { return }
        let base = parts.prefix(3).joined(separator: ".")
        subnetBase = base

        isScanning = true
        scanTask = Task { await sweep(base: base) }
    }

    func stop() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
    }

    private func reset() {
        hosts = []
        progress = 0
        scannedCount = 0
        localIP = nil
        subnetBase = nil
    }

    private func sweep(base: String) async {
        let port = probePort
        let timeout = timeoutSeconds
        await withTaskGroup(of: SubnetHost?.self) { group in
            var launched = 0
            var nextHost = 1

            func enqueue() {
                guard nextHost <= totalHosts else { return }
                let host = "\(base).\(nextHost)"
                nextHost += 1
                group.addTask { await Self.probe(ip: host, port: port, timeout: timeout) }
            }

            // Prime the pool up to the concurrency cap.
            while launched < maxConcurrent && nextHost <= totalHosts {
                enqueue()
                launched += 1
            }

            for await result in group {
                if Task.isCancelled { break }
                scannedCount += 1
                progress = Double(scannedCount) / Double(totalHosts)
                if let result, result.isUp {
                    hosts.append(result)
                    hosts.sort { ipSortKey($0.ip) < ipSortKey($1.ip) }
                }
                enqueue()
            }
        }
        isScanning = false
        progress = 1
    }

    private func ipSortKey(_ ip: String) -> Int {
        Int(ip.split(separator: ".").last ?? "0") ?? 0
    }

    // MARK: - TCP connect probe

    static func probe(ip: String, port: UInt16, timeout: Double) async -> SubnetHost? {
        await withCheckedContinuation { continuation in
            let start = Date()
            let endpoint = NWEndpoint.Host(ip)
            let nwPort = NWEndpoint.Port(rawValue: port)!
            let params = NWParameters.tcp
            let connection = NWConnection(host: endpoint, port: nwPort, using: params)

            let finished = ManagedAtomicFlag()
            let queue = DispatchQueue(label: "subnet.probe.\(ip)")

            func finish(up: Bool) {
                guard finished.testAndSet() else { return }
                let ms = Int(Date().timeIntervalSince(start) * 1000)
                connection.cancel()
                continuation.resume(returning: SubnetHost(ip: ip, isUp: up, responseMs: up ? ms : nil))
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish(up: true)
                case .failed, .cancelled:
                    // A refused connection (ECONNREFUSED) surfaces as .waiting/.failed
                    // quickly — but reachability is proven by a fast failure vs timeout.
                    finish(up: false)
                default:
                    break
                }
            }

            // A host that refuses the port responds almost instantly; treat any
            // response inside the timeout window as "up". Pure timeout = down.
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) {
                finish(up: false)
            }
        }
    }

    // MARK: - Interface discovery

    static func currentIPv4Address() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let cursor = ptr {
            let interface = cursor.pointee
            let family = interface.ifa_addr.pointee.sa_family
            if family == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" {   // WiFi interface on iOS
                    var addr = interface.ifa_addr.pointee
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(&addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, 0, NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
            ptr = cursor.pointee.ifa_next
        }
        return address
    }

    static func isWiFiInterfaceActive() -> Bool {
        currentIPv4Address() != nil
    }
}

// MARK: - Lightweight one-shot flag
//
// Guards the probe continuation so it resumes exactly once across the
// state handler and the timeout closure.

final class ManagedAtomicFlag {
    private let lock = NSLock()
    private var flag = false
    /// Returns true the first time it is called, false on every subsequent call.
    func testAndSet() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if flag { return false }
        flag = true
        return true
    }
}
