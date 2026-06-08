import SwiftUI

struct HTTPHeadersView: View {
    @StateObject private var inspector = HTTPHeadersInspector()
    @State private var urlText = ""
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Color.cyberBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                inputSection
                if inspector.isScanning { ProgressView().tint(.cyberGreen).padding() }
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if let result = inspector.result {
                            gradeCard(result)
                            ForEach(result.headers) { headerRow($0) }
                        } else if !inspector.isScanning {
                            Text("$ inspect security response headers")
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
        .navigationTitle("HTTP Headers")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var inputSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass").foregroundColor(.cyberGreen)
                TextField("https://example.com", text: $urlText)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .focused($focused)
                    .submitLabel(.go)
                    .onSubmit { launch() }
            }
            .padding(12)
            .background(Color.cyberBackground)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cyberBorder, lineWidth: 1))

            if let err = inspector.errorMessage {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11)).foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button { launch() } label: {
                Label("Analyze Headers", systemImage: "play.fill")
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

    private func gradeCard(_ result: HeaderScanResult) -> some View {
        HStack(spacing: 16) {
            Text(result.grade)
                .font(.system(size: 40, weight: .black, design: .monospaced))
                .foregroundColor(gradeColor(result.grade))
                .frame(width: 64, height: 64)
                .background(gradeColor(result.grade).opacity(0.15))
                .cornerRadius(12)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(result.score)/\(result.total) headers present")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                Text("HTTP \(result.statusCode)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.cyberGreen.opacity(0.8))
                Text("Server: \(result.server)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding()
        .background(Color.cyberSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyberBorder, lineWidth: 1))
    }

    private func headerRow(_ header: SecurityHeaderResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: header.present ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(header.present ? .cyberGreen : .red)
                Text(header.name)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                Spacer()
            }
            if header.present {
                Text(header.value)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.cyberCyan.opacity(0.8))
                    .lineLimit(2)
            }
            Text(header.explanation)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.45))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cyberSurface)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cyberBorder, lineWidth: 1))
    }

    private func gradeColor(_ grade: String) -> Color {
        switch grade {
        case "A": return .cyberGreen
        case "B": return .cyberCyan
        case "C": return .orange
        default:  return .red
        }
    }

    private func launch() {
        focused = false
        HapticFeedback.scanLaunch()
        inspector.scan(url: urlText)
    }
}
