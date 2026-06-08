import SwiftUI

struct ReverseIPView: View {
    @StateObject private var scanner = ReverseIPScanner()
    @State private var ip = ""
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
        .navigationTitle("Reverse IP")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var inputSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.swap").foregroundColor(.cyberGreen)
                TextField("8.8.8.8", text: $ip)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)
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
                Label("Reverse Lookup", systemImage: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Color.cyberGreen).cornerRadius(10)
                    .neonGlow(.cyberGreen, radius: 6)
            }

            if !scanner.domains.isEmpty {
                Text("\(scanner.count) domains found")
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
                if scanner.domains.isEmpty && !scanner.isScanning {
                    Text("$ find all domains sharing an IP address")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.cyberGreen.opacity(0.4))
                        .padding(.top, 30)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(scanner.domains) { entry in
                    Text(entry.domain)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.cyberGreen)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                    Divider().background(Color.cyberBorder)
                }
            }
            .padding()
        }
    }

    private func launch() {
        focused = false
        HapticFeedback.scanLaunch()
        scanner.scan(ip: ip)
    }
}
