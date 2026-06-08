import SwiftUI

struct SchedulesView: View {
    @EnvironmentObject private var client: APIClient
    @State private var schedules: [Schedule] = []
    @State private var targets: [Target] = []
    @State private var isLoading = false
    @State private var showCreate = false
    @State private var error: String?

    var body: some View {
        ZStack {
            Color.cyberBackground.ignoresSafeArea()

            if isLoading && schedules.isEmpty {
                ProgressView().tint(.cyberGreen)
            } else if schedules.isEmpty {
                emptyState
            } else {
                scheduleList
            }
        }
        .navigationTitle("Scheduled Scans")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showCreate = true } label: {
                    Image(systemName: "plus").foregroundColor(.cyberGreen)
                }
            }
        }
        .sheet(isPresented: $showCreate) {
            CreateScheduleView(targets: targets) { _ in
                Task { await load() }
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private var scheduleList: some View {
        List {
            ForEach(schedules) { schedule in
                ScheduleRow(schedule: schedule) { updated in
                    await toggleSchedule(updated)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task { await deleteSchedule(schedule) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.cyberBackground)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 52))
                .foregroundColor(.cyberGreen.opacity(0.5))
            Text("No Scheduled Scans")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            Text("Automate recurring scans to monitor targets continuously.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                showCreate = true
            } label: {
                Label("Create First Schedule", systemImage: "plus.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.cyberGreen)
                    .cornerRadius(10)
            }
        }
    }

    private func load() async {
        isLoading = true
        async let s: [Schedule] = (try? client.request(Endpoints.schedules)) ?? []
        async let t: [Target]   = (try? client.request(Endpoints.targets))   ?? []
        (schedules, targets) = await (s, t)
        isLoading = false
    }

    private func toggleSchedule(_ s: Schedule) async {
        let req = UpdateScheduleRequest(enabled: !s.enabled)
        _ = try? await client.request(Endpoints.updateSchedule(s.id, req)) as EmptyResponse?
        await load()
    }

    private func deleteSchedule(_ s: Schedule) async {
        _ = try? await client.request(Endpoints.deleteSchedule(s.id)) as EmptyResponse?
        schedules.removeAll { $0.id == s.id }
    }
}

struct ScheduleRow: View {
    let schedule: Schedule
    let onToggle: (Schedule) async -> Void
    @State private var isToggling = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(schedule.displayLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text(schedule.targetAddress)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.45))
                }
                Spacer()
                if isToggling {
                    ProgressView().tint(.cyberGreen).scaleEffect(0.75)
                } else {
                    Toggle("", isOn: .constant(schedule.enabled))
                        .tint(.cyberGreen)
                        .labelsHidden()
                        .onTapGesture {
                            isToggling = true
                            Task {
                                await onToggle(schedule)
                                isToggling = false
                            }
                        }
                }
            }

            HStack(spacing: 12) {
                pill(schedule.tool, icon: "terminal", color: .cyberGreen)
                pill(schedule.cronDisplayName, icon: "clock", color: .white.opacity(0.6))
            }

            if let next = schedule.nextRunAt {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                    Text("Next: \(next, style: .relative)")
                        .font(.system(size: 11))
                }
                .foregroundColor(.white.opacity(0.4))
            } else if let last = schedule.lastRunAt {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 10))
                    Text("Last: \(last, style: .relative)")
                        .font(.system(size: 11))
                }
                .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(14)
        .background(schedule.enabled ? Color.white.opacity(0.04) : Color.white.opacity(0.02))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(schedule.enabled ? Color.cyberGreen.opacity(0.2) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func pill(_ text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 9))
            Text(text).font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
}

struct CreateScheduleView: View {
    let targets: [Target]
    let onCreate: (Schedule) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var client: APIClient

    @State private var selectedTarget: Target?
    @State private var selectedTool = "nmap"
    @State private var selectedCron = CronPreset.allPresets[3]
    @State private var label = ""
    @State private var flags = ""
    @State private var isSaving = false
    @State private var error: String?

    let tools = ["nmap","nuclei","nikto","whatweb","testssl","openssl","gobuster",
                 "amass","subfinder","dns","whois","shodan","virustotal",
                 "abuseipdb","ipinfo","hibp"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cyberBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        if let error {
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundColor(.red)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                        }

                        formSection("Target") {
                            if targets.isEmpty {
                                Text("No targets — create one first")
                                    .foregroundColor(.white.opacity(0.4))
                                    .font(.system(size: 13))
                            } else {
                                Picker("Target", selection: $selectedTarget) {
                                    Text("Select…").tag(nil as Target?)
                                    ForEach(targets) { t in
                                        Text(t.name).tag(t as Target?)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(.cyberGreen)
                            }
                        }

                        formSection("Tool") {
                            Picker("Tool", selection: $selectedTool) {
                                ForEach(tools, id: \.self) { Text($0).tag($0) }
                            }
                            .pickerStyle(.menu)
                            .tint(.cyberGreen)
                        }

                        formSection("Frequency") {
                            Picker("Frequency", selection: $selectedCron) {
                                ForEach(CronPreset.allPresets) { p in
                                    Text(p.label).tag(p)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(.cyberGreen)
                        }

                        formSection("Label (optional)") {
                            TextField("e.g. Weekly nmap on homelab", text: $label)
                                .foregroundColor(.white)
                        }

                        formSection("Flags (optional)") {
                            TextField("e.g. -T4 -p 1-1024", text: $flags)
                                .foregroundColor(.white)
                                .font(.system(size: 13, design: .monospaced))
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("New Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(.white.opacity(0.6))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().tint(.cyberGreen).scaleEffect(0.8)
                        } else {
                            Text("Save").foregroundColor(.cyberGreen).fontWeight(.semibold)
                        }
                    }
                    .disabled(selectedTarget == nil || isSaving)
                }
            }
        }
    }

    @ViewBuilder
    private func formSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
            content()
                .padding(12)
                .background(Color.white.opacity(0.04))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
    }

    private func save() async {
        guard let target = selectedTarget else { return }
        isSaving = true
        error = nil
        let req = CreateScheduleRequest(
            targetId: target.id,
            tool: selectedTool,
            flags: flags,
            cronExpression: selectedCron.value,
            label: label.isEmpty ? nil : label
        )
        do {
            let schedule: Schedule = try await client.request(Endpoints.createSchedule(req))
            onCreate(schedule)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }
}
