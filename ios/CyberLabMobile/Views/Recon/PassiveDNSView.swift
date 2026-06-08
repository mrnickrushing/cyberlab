import SwiftUI

struct PassiveDNSView: View {
    @StateObject private var scanner = PassiveDNSScanner()
    @State private var domain = ""
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Color.cyberBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                inputSection
                if scanner.isScanning { ProgressView().tint(.cyberGreen).padding() }
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !scanner.currentDNS.isEmpty {
                            section(title: "Current DNS Records") {
                                Text(scanner.currentDNS)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.cyberGreen.opacity(0.85))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                        }
                        if !scanner.hosts.isEmpty {
                            section(title: "Historical Hosts (\(scanner.hosts.count))") {
                                ForEach(scanner.hosts) { host in
                                    HStack {
                                        Text(host.hostname)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text(host.ip)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(.cyberCyan)
                                    }
                                    .padding(.vertical, 4)
                                    Divider().background(Color.cyberBorder)
                                }
                            }
                        }
                        if scanner.currentDNS.isEmpty && scanner.hosts.isEmpty && !scanner.isScanning {
                            Text("$ enumerate DNS records and historical hosts")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.cyberGreen.opacity(0.4))
                                .padding(.top, 30)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Passive DNS")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var inputSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "globe.americas").foregroundColor(.cyberGreen)
                TextField("example.com", text: $domain)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .focused($focused)
                    .submitLabel(.search)
                    .onSubmit { launch() }
            }
            .padding(12)
            .background(Color.cyberBackground)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cyberBorder, lineWidth: 1))

            if let err = scanner.errorMessage {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11)).foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button { launch() } label: {
                Label("Lookup", systemImage: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Color.cyberGreen).cornerRadius(10)
                    .neonGlow(.cyberGreen, radius: 6)
            }
        }
        .padding()
        .background(Color.cyberSurface)
    }

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.cyberGreen)
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cyberSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyberBorder, lineWidth: 1))
    }

    private func launch() {
        focused = false
        HapticFeedback.scanLaunch()
        scanner.scan(domain: domain)
    }
}
