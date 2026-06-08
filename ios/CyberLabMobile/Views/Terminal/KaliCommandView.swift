import SwiftUI

struct KaliCommandView: View {
    @StateObject private var ws = KaliWSManager.shared
    @State private var target = ""
    @State private var customCmd = ""
    @State private var showSaveFinding = false
    @State private var autoScroll = true

    var body: some View {
        VStack(spacing: 0) {
            // Status bar
            HStack(spacing: 8) {
                Circle()
                    .fill(ws.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(ws.isConnected ? "RELAY CONNECTED" : "DISCONNECTED")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(ws.isConnected ? .green : .red)
                Spacer()
                Button("CTRL+C") { ws.sendCtrlC() }
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color(white: 0.08))

            // Target field
            HStack {
                Image(systemName: "scope").foregroundColor(.cyberGreen).font(.system(size: 13))
                TextField("Target IP or domain", text: $target)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color(white: 0.06))

            Divider().background(Color.cyberGreen.opacity(0.2))

            // Output terminal
            ScrollViewReader { proxy in
                ScrollView {
                    Text(ws.outputBuffer.isEmpty ? "// awaiting output..." : ws.outputBuffer)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(ws.outputBuffer.isEmpty ? .gray : .cyberGreen)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .id("bottom")
                }
                .background(Color.black)
                .frame(maxHeight: .infinity)
                .onChange(of: ws.outputBuffer) { _ in
                    if autoScroll {
                        withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                }
            }

            // Output actions
            HStack(spacing: 12) {
                Button {
                    ws.clearBuffer()
                } label: {
                    Label("Clear", systemImage: "trash")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.gray)
                }
                Button {
                    UIPasteboard.general.string = ws.outputBuffer
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.cyberGreen)
                }
                Spacer()
                if !ws.outputBuffer.isEmpty {
                    Button {
                        showSaveFinding = true
                    } label: {
                        Label("Save as Finding", systemImage: "plus.circle")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Color(white: 0.06))

            Divider().background(Color.cyberGreen.opacity(0.2))

            // Preset commands
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    presetGroup("RECON", color: .green, commands: [
                        ("Quick Scan", "nmap -sV \(target.isEmpty ? "<target>" : target)"),
                        ("Full Scan", "nmap -sC -sV -O \(target.isEmpty ? "<target>" : target)"),
                        ("WhatWeb", "whatweb \(target.isEmpty ? "<target>" : target)"),
                        ("WHOIS", "whois \(target.isEmpty ? "<target>" : target)"),
                    ])
                    presetGroup("ENUM", color: .cyan, commands: [
                        ("Gobuster", "gobuster dir -u \(target.isEmpty ? "<target>" : target) -w /usr/share/wordlists/dirb/common.txt"),
                        ("Nikto", "nikto -h \(target.isEmpty ? "<target>" : target)"),
                        ("Subfinder", "subfinder -d \(target.isEmpty ? "<target>" : target)"),
                    ])
                    presetGroup("NETWORK", color: .blue, commands: [
                        ("ARP Scan", "arp-scan -l"),
                        ("Netdiscover", "netdiscover -r 192.168.1.0/24"),
                        ("Ping Sweep", "nmap -sn 192.168.1.0/24"),
                    ])
                    presetGroup("UTILS", color: .gray, commands: [
                        ("Clear", "clear"),
                        ("Who am I", "whoami"),
                        ("System Info", "uname -a"),
                        ("List Files", "ls -la"),
                    ])
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
            }
            .background(Color(white: 0.05))

            // Custom command input
            HStack(spacing: 8) {
                Text("$").font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.cyberGreen)
                TextField("Custom command", text: $customCmd)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .onSubmit { runCustom() }
                Button("RUN") { runCustom() }
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.cyberGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .disabled(customCmd.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color(white: 0.06))
        }
        .background(Color.black)
        .onAppear { ws.connect() }
        .sheet(isPresented: $showSaveFinding) {
            KaliResultsView(command: customCmd, output: ws.outputBuffer)
        }
    }

    private func runCustom() {
        let cmd = customCmd.trimmingCharacters(in: .whitespaces)
        guard !cmd.isEmpty else { return }
        ws.sendCommand(cmd)
        customCmd = ""
    }

    @ViewBuilder
    private func presetGroup(_ title: String, color: Color, commands: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            HStack(spacing: 6) {
                ForEach(commands, id: \.0) { name, cmd in
                    Button {
                        ws.sendCommand(cmd)
                    } label: {
                        Text(name)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(color)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(color.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
    }
}
