import SwiftUI

struct CertTransparencyView: View {
    @StateObject private var scanner = CertTransparencyScanner()
    @State private var domain = ""
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Color.cyberBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                inputSection
                if scanner.isScanning { ProgressView().tint(.cyberGreen).padding() }
                resultsList
            }
        }
        .navigationTitle("Cert Transparency")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var inputSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield").foregroundColor(.cyberGreen)
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
                Label("Search crt.sh", systemImage: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Color.cyberGreen).cornerRadius(10)
                    .neonGlow(.cyberGreen, radius: 6)
            }

            if !scanner.entries.isEmpty {
                Text("\(scanner.subdomainCount) subdomains found")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.cyberCyan).cornerRadius(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color.cyberSurface)
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if scanner.entries.isEmpty && !scanner.isScanning {
                    Text("$ enumerate subdomains via certificate transparency logs")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.cyberGreen.opacity(0.4))
                        .padding(.top, 30)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(scanner.entries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.subdomain)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(.cyberGreen)
                        HStack {
                            Text(entry.issuer)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                                .lineLimit(1)
                            Spacer()
                            Text("exp \(entry.notAfter)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.orange.opacity(0.8))
                        }
                    }
                    .padding(.vertical, 7)
                    Divider().background(Color.cyberBorder)
                }
            }
            .padding()
        }
    }

    private func launch() {
        focused = false
        HapticFeedback.scanLaunch()
        scanner.scan(domain: domain)
    }
}
