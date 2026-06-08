import Foundation

// MARK: - SSH Terminal Manager
//
// iOS sandboxing prevents apps from opening raw outbound SSH sockets to
// arbitrary hosts without a Network Extension entitlement, and there is no
// system SSH client to shell out to. This manager therefore models a
// connection and produces the equivalent `ssh` command line plus a simulated
// session transcript for educational/demo purposes.

struct SSHConnection: Equatable {
    var host: String
    var port: String
    var username: String
    var password: String

    var commandString: String {
        let portPart = (port.isEmpty || port == "22") ? "" : " -p \(port)"
        let user = username.isEmpty ? "user" : username
        let target = host.isEmpty ? "host" : host
        return "ssh \(user)@\(target)\(portPart)"
    }
}

@MainActor
final class SSHTerminalManager: ObservableObject {
    @Published var transcript: [String] = []
    @Published var isConnected = false
    @Published var errorMessage: String?

    func connect(_ connection: SSHConnection) {
        let host = connection.host.trimmingCharacters(in: .whitespacesAndNewlines)
        let user = connection.username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty, !user.isEmpty else {
            errorMessage = "Host and username are required."
            return
        }
        errorMessage = nil

        let portLabel = connection.port.isEmpty ? "22" : connection.port
        transcript = [
            "$ \(connection.commandString)",
            "Connecting to \(host) on port \(portLabel)...",
            "The authenticity of host '\(host)' can't be established.",
            "ED25519 key fingerprint is SHA256:\(Self.fakeFingerprint()).",
            "Are you sure you want to continue connecting (yes/no)? yes",
            "Warning: Permanently added '\(host)' to the list of known hosts.",
            "\(user)@\(host)'s password: ********",
            "",
            "Welcome to Ubuntu 22.04.4 LTS (GNU/Linux 5.15.0 x86_64)",
            "",
            "Last login: \(Self.timestamp()) from 10.0.0.1",
            "\(user)@\(host):~$ ",
            "",
            "[ NOTE ] This is a simulated session. iOS app sandboxing prevents",
            "         native SSH. Copy the command above and run it from a real",
            "         terminal (macOS Terminal, iSH, Blink, etc.)."
        ]
        isConnected = true
    }

    func disconnect() {
        transcript = []
        isConnected = false
    }

    private static func fakeFingerprint() -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
        return String((0..<43).compactMap { _ in chars.randomElement() })
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE MMM d HH:mm:ss yyyy"
        return formatter.string(from: Date())
    }
}
