import SwiftUI

struct KaliResultsView: View {
    let command: String
    let output: String

    @Environment(\.dismiss) var dismiss
    @State private var title: String = ""
    @State private var severity: FindingSeverity = .medium
    @State private var targetId: String = ""
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var didSave = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Command preview
                    VStack(alignment: .leading, spacing: 6) {
                        Text("COMMAND")
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                            .foregroundColor(.cyberGreen)
                        Text(command.isEmpty ? "Custom command" : command)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color(white: 0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("FINDING TITLE")
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                            .foregroundColor(.cyberGreen)
                        TextField("Title", text: $title)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color(white: 0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Severity
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SEVERITY")
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                            .foregroundColor(.cyberGreen)
                        HStack(spacing: 8) {
                            ForEach(FindingSeverity.allCases, id: \.self) { s in
                                Button {
                                    severity = s
                                } label: {
                                    Text(s.rawValue.uppercased())
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(severity == s ? .black : severityColor(s))
                                        .padding(.horizontal, 8).padding(.vertical, 4)
                                        .background(severity == s ? severityColor(s) : severityColor(s).opacity(0.15))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    // Output preview
                    VStack(alignment: .leading, spacing: 8) {
                        Text("OUTPUT PREVIEW (first 500 chars)")
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                            .foregroundColor(.cyberGreen)
                        Text(String(output.prefix(500)))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.green)
                            .padding(10)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cyberGreen.opacity(0.3)))
                    }

                    if let err = saveError {
                        Text(err).font(.system(.caption, design: .monospaced)).foregroundColor(.red)
                    }
                    if didSave {
                        Text("✓ Finding saved").font(.system(.caption, design: .monospaced)).foregroundColor(.cyberGreen)
                    }
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Save as Finding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(.gray)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSaving {
                        ProgressView().tint(.cyberGreen)
                    } else {
                        Button("Save") { Task { await saveFinding() } }
                            .foregroundColor(.cyberGreen)
                            .font(.system(.body, design: .monospaced, weight: .bold))
                            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .onAppear {
            title = command.isEmpty ? "Kali Terminal Output" : "[\(command.prefix(40))]"
        }
    }

    func saveFinding() async {
        isSaving = true
        saveError = nil
        let description = "Command: \(command)\n\nOutput:\n\(String(output.prefix(2000)))"
        let req = CreateFindingRequest(
            targetId: targetId.isEmpty ? "unknown" : targetId,
            title: title,
            severity: severity,
            description: description,
            remediation: nil,
            cvssScore: nil,
            cveId: nil
        )
        guard let url = URL(string: "\(APIConfig.baseURL)/findings") else { isSaving = false; return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = AuthManager.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try? JSONEncoder().encode(req)
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 201 || http.statusCode == 200 {
                didSave = true
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                dismiss()
            } else {
                saveError = "Failed to save. Check target ID and try again."
            }
        } catch {
            saveError = error.localizedDescription
        }
        isSaving = false
    }

    func severityColor(_ s: FindingSeverity) -> Color {
        switch s {
        case .critical: return .red
        case .high:     return .orange
        case .medium:   return .yellow
        case .low:      return .blue
        case .info:     return .gray
        }
    }
}
