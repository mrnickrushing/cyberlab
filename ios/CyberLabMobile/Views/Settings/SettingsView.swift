import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var biometricManager: BiometricAuthManager
    @StateObject private var lockManager = BiometricLockManager.shared
    @AppStorage("soundEnabled") private var soundEnabled = true
    @State private var serverURL = ""
    @State private var showServerURLEditor = false
    @State private var savedMessage = ""
    private let client = APIClient.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cyberBackground.ignoresSafeArea()
                Form {
                    // Profile
                    Section {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color.cyberGreen.opacity(0.2))
                                    .frame(width: 50, height: 50)
                                Image(systemName: "person.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.cyberGreen)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(authManager.currentUser?.username ?? "Operator")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                Text(authManager.currentUser?.email ?? "")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .padding(.vertical, 4)

                        LabeledContent("Legal Status") {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(authManager.legalAcknowledged ? Color.cyberGreen : Color.orange)
                                    .frame(width: 8, height: 8)
                                Text(authManager.legalAcknowledged ? "Acknowledged" : "Pending")
                                    .font(.system(size: 13))
                                    .foregroundColor(authManager.legalAcknowledged ? .cyberGreen : .orange)
                            }
                        }
                    } header: {
                        Text("Operator")
                    }

                    // Server
                    Section {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("API Server")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                Text(client.baseURL)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.4))
                                    .lineLimit(1)
                            }
                            Spacer()
                            Button("Edit") { showServerURLEditor = true }
                                .font(.system(size: 13))
                                .foregroundColor(.cyberGreen)
                        }
                        if !savedMessage.isEmpty {
                            Text(savedMessage)
                                .font(.caption)
                                .foregroundColor(.cyberGreen)
                        }
                    } header: {
                        Text("Connection")
                    }

                    // Biometrics
                    if biometricManager.isBiometricAvailable {
                        Section {
                            LabeledContent(biometricManager.biometricLabel) {
                                Image(systemName: biometricManager.biometricSystemImage)
                                    .foregroundColor(.cyberGreen)
                            }

                            Toggle(isOn: $lockManager.isEnabled) {
                                Label("Per-Section Lock", systemImage: "lock.shield")
                                    .foregroundColor(.white)
                            }
                            .tint(.cyberGreen)

                            if lockManager.isEnabled {
                                ForEach(BiometricLockManager.allSections, id: \.key) { section in
                                    Toggle(isOn: Binding(
                                        get: { lockManager.lockedSections.contains(section.key) },
                                        set: { lockManager.toggleSection(section.key, on: $0) }
                                    )) {
                                        Text(section.label)
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.85))
                                    }
                                    .tint(.cyberGreen)
                                }
                            }
                        } header: {
                            Text("Security")
                        } footer: {
                            if lockManager.isEnabled {
                                Text("Selected sections require a fresh \(biometricManager.biometricLabel) check each time.")
                            }
                        }
                    }

                    // Operator
                    Section {
                        NavigationLink {
                            OperatorProfileView()
                        } label: {
                            Label("Operator Profile", systemImage: "shield.lefthalf.filled")
                                .foregroundColor(.white)
                        }
                    } header: {
                        Text("Progression")
                    }

                    // Terminal SFX
                    Section {
                        Toggle(isOn: $soundEnabled) {
                            Label("Terminal SFX", systemImage: "speaker.wave.2.fill")
                                .foregroundColor(.white)
                        }
                        .tint(.cyberGreen)
                    } header: {
                        Text("Sound")
                    } footer: {
                        Text("Plays system sounds on scan start, completion, and critical findings.")
                    }

                    // Automation
                    Section {
                        NavigationLink {
                            SchedulesView()
                        } label: {
                            Label("Scheduled Scans", systemImage: "calendar.badge.clock")
                                .foregroundColor(.white)
                        }
                    } header: {
                        Text("Automation")
                    }

                    // App Info
                    Section {
                        LabeledContent("Version", value: "1.0.0 (Phase 1)")
                        LabeledContent("Build", value: "ios-phase1")
                        LabeledContent("Backend", value: "Node.js / Express")
                        LabeledContent("Database", value: "PostgreSQL + Drizzle")
                    } header: {
                        Text("About")
                    }

                    // Legal
                    Section {
                        NavigationLink("Legal Notice") {
                            LegalNoticeView()
                        }
                    } header: {
                        Text("Legal")
                    }

                    // Logout
                    Section {
                        Button(role: .destructive) {
                            authManager.logout()
                        } label: {
                            HStack {
                                Spacer()
                                Label("Log Out", systemImage: "arrow.right.square")
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showServerURLEditor) {
                ServerURLEditor(current: client.baseURL) { newURL in
                    client.setServerURL(newURL)
                    savedMessage = "Saved"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { savedMessage = "" }
                }
            }
        }
    }
}

struct ServerURLEditor: View {
    @Environment(\.dismiss) var dismiss
    let current: String
    let onSave: (String) -> Void
    @State private var url = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cyberBackground.ignoresSafeArea()
                Form {
                    Section("API Server URL") {
                        TextField("https://your-api.railway.app/api", text: $url)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .font(.system(size: 13, design: .monospaced))
                    }
                    Section {
                        Text("Enter your Railway (or other) backend URL. Must include /api at the end.")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Server URL")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(url); dismiss() }.disabled(url.isEmpty)
                }
            }
            .onAppear { url = current }
        }
    }
}

struct LegalNoticeView: View {
    var body: some View {
        ZStack {
            Color.cyberBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Legal & Ethical Use")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text(legalText)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(20)
            }
        }
        .navigationTitle("Legal Notice")
        .navigationBarTitleDisplayMode(.inline)
    }

    let legalText = """
    CyberLab Mobile is built for personal cybersecurity labs, owned networks, and authorized security testing only.

    Always obtain written authorization before scanning any system you do not own.

    Never use this tool to scan public infrastructure, third-party systems, or networks without explicit permission.

    Unauthorized scanning may violate the Computer Fraud and Abuse Act (CFAA), the UK Computer Misuse Act, and equivalent laws in your jurisdiction.

    The authorization checkbox and audit log exist to help you stay compliant — use them honestly.

    The developer assumes no liability for misuse. You are solely responsible for your actions.
    """
}
