import SwiftUI

struct FindingNotesView: View {
    let finding: Finding
    @Environment(\.dismiss) var dismiss
    @State private var title: String = ""
    @State private var body_: String = ""
    @State private var tags: String = ""
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var didSave = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Finding context card
                    VStack(alignment: .leading, spacing: 6) {
                        Text("FINDING")
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                            .foregroundColor(.cyberGreen)
                        Text(finding.title)
                            .font(.system(.body, design: .monospaced, weight: .bold))
                            .foregroundColor(.white)
                        Text(finding.severity.rawValue.uppercased())
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(severityColor(finding.severity))
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(white: 0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // Note fields
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NOTE TITLE")
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                            .foregroundColor(.cyberGreen)
                        TextField("Title", text: $title)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color(white: 0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("NOTES")
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                            .foregroundColor(.cyberGreen)
                        TextEditor(text: $body_)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.white)
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .frame(minHeight: 160)
                            .background(Color(white: 0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("TAGS (comma separated)")
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                            .foregroundColor(.cyberGreen)
                        TextField("e.g. critical, recon, webapp", text: $tags)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color(white: 0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    if let err = saveError {
                        Text(err)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.red)
                    }

                    if didSave {
                        Text("✓ Note saved")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.cyberGreen)
                    }
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Add Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(.gray)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSaving {
                        ProgressView().tint(.cyberGreen)
                    } else {
                        Button("Save") { Task { await saveNote() } }
                            .foregroundColor(.cyberGreen)
                            .font(.system(.body, design: .monospaced, weight: .bold))
                            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .onAppear {
            title = finding.title
        }
    }

    func saveNote() async {
        isSaving = true
        saveError = nil
        let tagList = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let req = CreateNoteRequest(
            title: title,
            body: body_,
            targetId: finding.targetId,
            tags: tagList.isEmpty ? nil : tagList
        )
        // Use the same API pattern as the rest of the app
        guard let url = URL(string: "\(APIClient.shared.baseURL)/notes") else { isSaving = false; return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = KeychainManager.load(.accessToken) {
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
                saveError = "Failed to save note. Try again."
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
