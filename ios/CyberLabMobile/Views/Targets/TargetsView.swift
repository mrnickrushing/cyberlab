import SwiftUI

struct TargetsView: View {
    @State private var targets: [Target] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var searchText = ""
    @State private var showAddTarget = false
    @State private var showArchived = false
    private let client = APIClient.shared

    var filtered: [Target] {
        targets.filter { t in
            (showArchived ? t.isArchived : !t.isArchived) &&
            (searchText.isEmpty || t.name.localizedCaseInsensitiveContains(searchText) ||
             t.address.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cyberBackground.ignoresSafeArea()
                Group {
                    if isLoading {
                        ProgressView().tint(.cyberGreen)
                    } else if let error {
                        ErrorView(message: error) { Task { await loadTargets() } }
                    } else if filtered.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "target")
                                .font(.system(size: 40))
                                .foregroundColor(.cyberGreen.opacity(0.4))
                            Text(targets.isEmpty ? "No targets yet" : "No results")
                                .foregroundColor(.white.opacity(0.4))
                        }
                    } else {
                        List {
                            ForEach(filtered) { target in
                                NavigationLink(destination: TargetDetailView(target: target)) {
                                    TargetRow(target: target)
                                }
                                .listRowBackground(Color.cyberSurface)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        Task { await deleteTarget(target) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    Button {
                                        Task { await archiveTarget(target) }
                                    } label: {
                                        Label(target.isArchived ? "Unarchive" : "Archive", systemImage: "archivebox")
                                    }
                                    .tint(.orange)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search targets")
            .navigationTitle("Targets")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        withAnimation { showArchived.toggle() }
                    } label: {
                        Label(showArchived ? "Active" : "Archived",
                              systemImage: showArchived ? "tray.full" : "archivebox")
                            .foregroundColor(.cyberGreen)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddTarget = true } label: {
                        Image(systemName: "plus.circle.fill").foregroundColor(.cyberGreen)
                    }
                }
            }
            .sheet(isPresented: $showAddTarget) {
                AddTargetView { Task { await loadTargets() } }
            }
            .refreshable { await loadTargets() }
        }
        .task { await loadTargets() }
    }

    private func loadTargets() async {
        isLoading = true; error = nil
        do {
            targets = try await client.request(Endpoints.targets)
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }

    private func deleteTarget(_ target: Target) async {
        do {
            try await client.requestVoid(Endpoints.deleteTarget(target.id))
            await loadTargets()
        } catch {}
    }

    private func archiveTarget(_ target: Target) async {
        do {
            let _: Target = try await client.request(Endpoints.archiveTarget(target.id))
            await loadTargets()
        } catch {}
    }
}

struct TargetRow: View {
    let target: Target
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.cyberBackground)
                    .frame(width: 40, height: 40)
                Image(systemName: target.type.systemImage)
                    .font(.system(size: 16))
                    .foregroundColor(.cyberGreen)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(target.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(target.address)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                StatusBadge(text: target.authorizationStatus.label, color: target.authorizationStatus.color)
                StatusBadge(text: target.riskLevel.label, color: target.riskLevel.color)
            }
        }
        .padding(.vertical, 4)
    }
}
