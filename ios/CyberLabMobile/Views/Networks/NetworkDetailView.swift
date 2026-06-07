import SwiftUI

enum NetworkTab: String, CaseIterable {
    case list = "Devices"
    case topology = "Topology"
    case diff = "Diff"
}

struct NetworkDetailView: View {
    let map: NetworkMap
    @State private var hosts: [NetworkHost] = []
    @State private var isLoading = true
    @State private var isScanning = false
    @State private var scanJobId: String?
    @State private var scanStatus: ScanStatus = .pending
    @State private var error: String?
    @State private var selectedTab: NetworkTab = .list
    @State private var allMaps: [NetworkMap] = []
    @State private var pollTimer: Timer?
    private let client = APIClient.shared

    var body: some View {
        ZStack {
            Color.cyberBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                mapHeader
                tabPicker
                    .padding(.horizontal)
                    .padding(.top, 8)
                tabContent
            }
        }
        .navigationTitle(map.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await startDiscovery() }
                } label: {
                    if isScanning {
                        ProgressView().tint(.cyberGreen).scaleEffect(0.8)
                    } else {
                        Label("Discover", systemImage: "antenna.radiowaves.left.and.right")
                            .foregroundColor(.cyberGreen)
                    }
                }
                .disabled(isScanning)
            }
        }
        .task {
            await loadHosts()
            await loadAllMaps()
        }
        .onDisappear { pollTimer?.invalidate() }
    }

    private var mapHeader: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 2) {
                Text(map.subnet)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.cyberGreen)
                Text("Last scanned \(map.scannedAt.relativeTime)")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(hosts.count)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                Text("hosts")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(hosts.filter(\.isTrusted).count)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.cyberGreen)
                Text("trusted")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color.cyberSurface)
    }

    private var tabPicker: some View {
        Picker("Tab", selection: $selectedTab) {
            ForEach(NetworkTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .colorMultiply(.cyberGreen)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .list:
            listTab
        case .topology:
            NetworkTopologyView(hosts: hosts)
        case .diff:
            NetworkDiffView(currentHosts: hosts, subnet: map.subnet, allMaps: allMaps.filter { $0.id != map.id })
        }
    }

    private var listTab: some View {
        Group {
            if isScanning {
                VStack(spacing: 16) {
                    Spacer()
                    ProgressView().tint(.cyberGreen).scaleEffect(1.5)
                    Text("Scanning \(map.subnet)…")
                        .foregroundColor(.white.opacity(0.6))
                        .font(.system(size: 14))
                    Text(scanStatus == .running ? "Discovering hosts" : "Queued")
                        .foregroundColor(.white.opacity(0.35))
                        .font(.system(size: 12))
                    Spacer()
                }
            } else if isLoading {
                ProgressView().tint(.cyberGreen).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if hosts.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.cyberGreen.opacity(0.4))
                    Text("No hosts discovered yet")
                        .foregroundColor(.white.opacity(0.4))
                    Text("Tap Discover to scan the subnet")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.25))
                    Spacer()
                }
            } else {
                List {
                    if let error {
                        Section {
                            Text(error).foregroundColor(.red).font(.system(size: 13))
                        }
                        .listRowBackground(Color.cyberSurface)
                    }
                    Section {
                        ForEach(hosts) { host in
                            NetworkHostRow(host: host) { updated in
                                Task { await updateHost(updated) }
                            }
                            .listRowBackground(Color.cyberSurface)
                        }
                    } header: {
                        Text("\(hosts.count) HOSTS")
                            .foregroundColor(.white.opacity(0.4))
                            .font(.system(size: 11, weight: .semibold))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private func loadHosts() async {
        isLoading = true
        do {
            hosts = try await client.request(Endpoints.networkHosts(map.id))
        } catch {}
        isLoading = false
    }

    private func loadAllMaps() async {
        do {
            allMaps = try await client.request(Endpoints.networks)
        } catch {}
    }

    private func startDiscovery() async {
        isScanning = true; error = nil
        do {
            let resp: DiscoverNetworkResponse = try await client.request(Endpoints.discoverNetwork(map.id))
            scanJobId = resp.scanJobId
            startPolling(jobId: resp.scanJobId)
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
            isScanning = false
        }
    }

    private func startPolling(jobId: String) {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { _ in
            Task { @MainActor in
                do {
                    let job: ScanJob = try await client.request(Endpoints.scan(jobId))
                    scanStatus = job.status
                    if job.status == .completed {
                        pollTimer?.invalidate()
                        isScanning = false
                        await loadHosts()
                    } else if job.status == .failed || job.status == .cancelled {
                        pollTimer?.invalidate()
                        isScanning = false
                        error = job.errorMessage ?? "Discovery failed"
                    }
                } catch {
                    pollTimer?.invalidate()
                    isScanning = false
                }
            }
        }
    }

    private func updateHost(_ host: NetworkHost) async {
        do {
            let req = UpdateNetworkHostRequest(isTrusted: host.isTrusted, isGateway: host.isGateway, hostname: host.hostname)
            let updated: NetworkHost = try await client.request(Endpoints.updateNetworkHost(map.id, host.id, req))
            if let idx = hosts.firstIndex(where: { $0.id == updated.id }) {
                hosts[idx] = updated
            }
        } catch {}
    }
}

struct NetworkHostRow: View {
    let host: NetworkHost
    let onUpdate: (NetworkHost) -> Void
    @State private var localHost: NetworkHost

    init(host: NetworkHost, onUpdate: @escaping (NetworkHost) -> Void) {
        self.host = host
        self.onUpdate = onUpdate
        _localHost = State(initialValue: host)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: iconName)
                    .font(.system(size: 15))
                    .foregroundColor(iconColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(localHost.ipAddress)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                    if localHost.isGateway {
                        StatusBadge(text: "GW", color: .blue)
                    }
                    if localHost.isTrusted {
                        StatusBadge(text: "Trusted", color: .cyberGreen)
                    }
                }
                if let hostname = localHost.hostname, !hostname.isEmpty {
                    Text(hostname)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
                if let mac = localHost.macAddress {
                    Text(mac)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                if let vendor = localHost.vendor, !vendor.isEmpty {
                    Text(vendor)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(1)
                }
                Menu {
                    Button {
                        localHost = NetworkHost(id: localHost.id, networkMapId: localHost.networkMapId,
                            ipAddress: localHost.ipAddress, macAddress: localHost.macAddress,
                            hostname: localHost.hostname, vendor: localHost.vendor,
                            isTrusted: !localHost.isTrusted, isGateway: localHost.isGateway,
                            firstSeen: localHost.firstSeen, lastSeen: localHost.lastSeen)
                        onUpdate(localHost)
                    } label: {
                        Label(localHost.isTrusted ? "Mark Untrusted" : "Mark Trusted",
                              systemImage: localHost.isTrusted ? "xmark.shield" : "checkmark.shield")
                    }
                    Button {
                        localHost = NetworkHost(id: localHost.id, networkMapId: localHost.networkMapId,
                            ipAddress: localHost.ipAddress, macAddress: localHost.macAddress,
                            hostname: localHost.hostname, vendor: localHost.vendor,
                            isTrusted: localHost.isTrusted, isGateway: !localHost.isGateway,
                            firstSeen: localHost.firstSeen, lastSeen: localHost.lastSeen)
                        onUpdate(localHost)
                    } label: {
                        Label(localHost.isGateway ? "Unmark Gateway" : "Mark as Gateway",
                              systemImage: localHost.isGateway ? "minus.circle" : "star.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.white.opacity(0.4))
                        .font(.system(size: 18))
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        if localHost.isGateway { return "wifi.router.fill" }
        if localHost.isTrusted { return "checkmark.shield.fill" }
        return "questionmark.circle.fill"
    }

    private var iconColor: Color {
        if localHost.isGateway { return .blue }
        if localHost.isTrusted { return .cyberGreen }
        return .orange
    }
}
