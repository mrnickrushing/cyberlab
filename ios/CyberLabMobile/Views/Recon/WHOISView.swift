import SwiftUI

struct WHOISView: View {
    @StateObject private var lookup = WHOISLookup()
    @State private var domain = ""
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Color.cyberBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                inputSection
                if lookup.isScanning { ProgressView().tint(.cyberGreen).padding() }
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let result = lookup.result {
                            highlights(result)
                            rawSection(result.raw)
                        } else if !lookup.isScanning {
                            Text("$ query WHOIS registration data")
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
        .navigationTitle("WHOIS")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var inputSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "person.text.rectangle").foregroundColor(.cyberGreen)
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

            if let err = lookup.errorMessage {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11)).foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button { launch() } label: {
                Label("WHOIS Lookup", systemImage: "magnifyingglass")
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

    private func highlights(_ result: WHOISResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            highlightRow("Registrar", result.registrar)
            highlightRow("Created", result.created)
            highlightRow("Expires", result.expires)
            if !result.nameservers.isEmpty {
                highlightRow("Nameservers", result.nameservers.joined(separator: "\n"))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cyberSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyberBorder, lineWidth: 1))
    }

    private func highlightRow(_ label: String, _ value: String?) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.cyberGreen)
                .frame(width: 100, alignment: .leading)
            Text(value?.isEmpty == false ? value! : "—")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func rawSection(_ raw: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Raw WHOIS")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.cyberGreen)
            Text(raw)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
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
        lookup.lookup(domain: domain)
    }
}
