import SwiftUI

struct SSHTerminalView: View {
    @StateObject private var manager = SSHTerminalManager()
    @State private var host = ""
    @State private var port = "22"
    @State private var username = ""
    @State private var password = ""
    @State private var copied = false

    private var connection: SSHConnection {
        SSHConnection(host: host, port: port, username: username, password: password)
    }

    var body: some View {
        ZStack {
            Color.cyberBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    infoCard
                    formCard
                    if manager.isConnected {
                        terminalWindow
                    }
                }
                .padding()
            }
        }
        .navigationTitle("SSH Terminal")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var infoCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill").foregroundColor(.cyberCyan)
            Text("iOS app sandboxing prevents native outbound SSH. This builds the connection command and a demo session — copy the command into a real terminal (Blink, iSH, macOS Terminal) to connect.")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cyberCyan.opacity(0.08))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyberCyan.opacity(0.3), lineWidth: 1))
    }

    private var formCard: some View {
        VStack(spacing: 12) {
            field(icon: "server.rack", placeholder: "host or IP", text: $host, keyboard: .URL)
            field(icon: "number", placeholder: "port", text: $port, keyboard: .numberPad)
            field(icon: "person", placeholder: "username", text: $username, keyboard: .default)
            secureField(icon: "key", placeholder: "password", text: $password)

            if let err = manager.errorMessage {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11)).foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 10) {
                Button {
                    HapticFeedback.scanLaunch()
                    manager.connect(connection)
                } label: {
                    Label("Connect", systemImage: "bolt.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color.cyberGreen).cornerRadius(10)
                }
                Button {
                    UIPasteboard.general.string = connection.commandString
                    HapticFeedback.success()
                    withAnimation { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { copied = false }
                    }
                } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.cyberGreen)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color.cyberBackground).cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyberGreen.opacity(0.4), lineWidth: 1))
                }
            }
        }
        .padding()
        .background(Color.cyberSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyberBorder, lineWidth: 1))
    }

    private var terminalWindow: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Circle().fill(Color.red).frame(width: 11, height: 11)
                Circle().fill(Color.yellow).frame(width: 11, height: 11)
                Circle().fill(Color.green).frame(width: 11, height: 11)
                Spacer()
                Text(connection.commandString)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color(white: 0.12))

            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(manager.transcript.enumerated()), id: \.offset) { _, line in
                    Text(line.isEmpty ? " " : line)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(lineColor(line))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black)
        }
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyberBorder, lineWidth: 1))
    }

    private func lineColor(_ line: String) -> Color {
        if line.hasPrefix("$") { return .cyberCyan }
        if line.hasPrefix("[ NOTE ]") || line.contains("simulated") { return .orange.opacity(0.85) }
        if line.contains("Welcome") { return .cyberGreen }
        return .cyberGreen.opacity(0.8)
    }

    private func field(icon: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(.cyberGreen).frame(width: 20)
            TextField(placeholder, text: text)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboard)
        }
        .padding(12)
        .background(Color.cyberBackground)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cyberBorder, lineWidth: 1))
    }

    private func secureField(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(.cyberGreen).frame(width: 20)
            SecureField(placeholder, text: text)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(12)
        .background(Color.cyberBackground)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cyberBorder, lineWidth: 1))
    }
}
