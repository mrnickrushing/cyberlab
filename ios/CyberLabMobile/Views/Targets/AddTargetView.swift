import SwiftUI

struct AddTargetView: View {
    @Environment(\.dismiss) var dismiss
    let onCreated: () -> Void

    @State private var name = ""
    @State private var address = ""
    @State private var type: TargetType = .ip
    @State private var authStatus: AuthorizationStatus = .pending
    @State private var riskLevel: RiskLevel = .medium
    @State private var owner = ""
    @State private var notes = ""
    @State private var isLoading = false
    @State private var error = ""
    private let client = APIClient.shared

    var isValid: Bool { !name.isEmpty && !address.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cyberBackground.ignoresSafeArea()
                Form {
                    Section("Target Info") {
                        TextField("Name", text: $name)
                        TextField("Address (IP / Domain / CIDR)", text: $address)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        Picker("Type", selection: $type) {
                            ForEach(TargetType.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                    }
                    Section("Authorization") {
                        Picker("Status", selection: $authStatus) {
                            ForEach(AuthorizationStatus.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                        Picker("Risk Level", selection: $riskLevel) {
                            ForEach(RiskLevel.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                    }
                    Section("Details (Optional)") {
                        TextField("Owner", text: $owner)
                        TextField("Notes", text: $notes, axis: .vertical)
                            .lineLimit(3, reservesSpace: true)
                    }
                    if !error.isEmpty {
                        Section { Text(error).foregroundColor(.red).font(.caption) }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Add Target")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { Task { await submit() } }
                        .disabled(!isValid || isLoading)
                }
            }
        }
    }

    private func submit() async {
        isLoading = true; error = ""
        defer { isLoading = false }
        do {
            let req = CreateTargetRequest(
                name: name, type: type, address: address,
                authorizationStatus: authStatus, riskLevel: riskLevel,
                owner: owner.isEmpty ? nil : owner,
                notes: notes.isEmpty ? nil : notes,
                tags: nil
            )
            let _: Target = try await client.request(Endpoints.createTarget(req))
            onCreated()
            dismiss()
        } catch let e as APIError {
            error = e.errorDescription ?? "Failed to create target"
        } catch {
            self.error = error.localizedDescription
        }
    }
}
