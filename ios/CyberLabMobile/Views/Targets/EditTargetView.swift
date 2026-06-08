import SwiftUI

struct EditTargetView: View {
    @Environment(\.dismiss) var dismiss
    let target: Target
    let onUpdated: (Target) -> Void

    @State private var authStatus: AuthorizationStatus
    @State private var riskLevel: RiskLevel
    @State private var owner: String
    @State private var isLoading = false
    @State private var error = ""
    private let client = APIClient.shared

    init(target: Target, onUpdated: @escaping (Target) -> Void) {
        self.target = target
        self.onUpdated = onUpdated
        _authStatus = State(initialValue: target.authorizationStatus)
        _riskLevel = State(initialValue: target.riskLevel)
        _owner = State(initialValue: target.owner ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cyberBackground.ignoresSafeArea()
                Form {
                    Section("Authorization") {
                        Picker("Status", selection: $authStatus) {
                            ForEach(AuthorizationStatus.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                        Picker("Risk Level", selection: $riskLevel) {
                            ForEach(RiskLevel.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                    }
                    Section("Details") {
                        TextField("Owner", text: $owner)
                    }
                    if !error.isEmpty {
                        Section { Text(error).foregroundColor(.red).font(.caption) }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Edit \(target.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(isLoading)
                }
            }
        }
    }

    private func save() async {
        isLoading = true; error = ""
        defer { isLoading = false }
        do {
            let req = UpdateTargetRequest(
                name: nil,
                authorizationStatus: authStatus,
                riskLevel: riskLevel,
                owner: owner.isEmpty ? nil : owner,
                notes: nil,
                tags: nil
            )
            let updated: Target = try await client.request(Endpoints.updateTarget(target.id, req))
            onUpdated(updated)
            dismiss()
        } catch let e as APIError {
            error = e.errorDescription ?? "Failed to update target"
        } catch {
            self.error = error.localizedDescription
        }
    }
}
