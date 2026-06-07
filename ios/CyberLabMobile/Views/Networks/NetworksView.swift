import SwiftUI

struct NetworksView: View {
    @State private var maps: [NetworkMap] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var showCreate = false
    private let client = APIClient.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cyberBackground.ignoresSafeArea()
                Group {
                    if isLoading {
                        ProgressView().tint(.cyberGreen)
                    } else if let error {
                        ErrorView(message: error) { Task { await load() } }
                    } else if maps.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "network")
                                .font(.system(size: 44))
                                .foregroundColor(.cyberGreen.opacity(0.4))
                            Text("No network maps yet")
                                .foregroundColor(.white.opacity(0.5))
                                .font(.system(size: 15))
                            Text("Create a map to start discovering devices")
                                .foregroundColor(.white.opacity(0.3))
                                .font(.system(size: 13))
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else {
                        List {
                            ForEach(maps) { map in
                                NavigationLink(destination: NetworkDetailView(map: map)) {
                                    NetworkMapRow(map: map)
                                }
                                .listRowBackground(Color.cyberSurface)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task { await deleteMap(map) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Network Maps")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showCreate = true } label: {
                        Image(systemName: "plus.circle.fill").foregroundColor(.cyberGreen)
                    }
                }
            }
            .sheet(isPresented: $showCreate) {
                CreateNetworkMapSheet { Task { await load() } }
            }
            .refreshable { await load() }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true; error = nil
        do {
            maps = try await client.request(Endpoints.networks)
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }

    private func deleteMap(_ map: NetworkMap) async {
        do {
            try await client.requestVoid(Endpoints.deleteNetwork(map.id))
            await load()
        } catch {}
    }
}

struct NetworkMapRow: View {
    let map: NetworkMap
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.cyberBackground)
                    .frame(width: 40, height: 40)
                Image(systemName: "network")
                    .font(.system(size: 18))
                    .foregroundColor(.cyberGreen)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(map.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(map.subnet)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if let hosts = map.hosts {
                    Text("\(hosts.count) hosts")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.cyberGreen)
                }
                Text(map.scannedAt.relativeTime)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.35))
            }
        }
        .padding(.vertical, 4)
    }
}

struct CreateNetworkMapSheet: View {
    let onCreated: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var subnet = "192.168.1.0/24"
    @State private var isSaving = false
    @State private var error: String?
    private let client = APIClient.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cyberBackground.ignoresSafeArea()
                Form {
                    Section {
                        TextField("e.g. Home Lab", text: $name)
                            .foregroundColor(.white)
                        TextField("e.g. 192.168.1.0/24", text: $subnet)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.cyberGreen)
                            .keyboardType(.asciiCapable)
                            .autocorrectionDisabled()
                    } header: {
                        Text("Map Details").foregroundColor(.white.opacity(0.5))
                    }
                    .listRowBackground(Color.cyberSurface)

                    if let error {
                        Section {
                            Text(error).foregroundColor(.red).font(.system(size: 13))
                        }
                        .listRowBackground(Color.cyberSurface)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Network Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.cyberGreen)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await save() }
                    }
                    .foregroundColor(.cyberGreen)
                    .disabled(name.isEmpty || subnet.isEmpty || isSaving)
                }
            }
        }
    }

    private func save() async {
        isSaving = true; error = nil
        do {
            let req = CreateNetworkMapRequest(name: name, subnet: subnet, targetId: nil)
            let _: NetworkMap = try await client.request(Endpoints.createNetwork(req))
            onCreated()
            dismiss()
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        isSaving = false
    }
}
