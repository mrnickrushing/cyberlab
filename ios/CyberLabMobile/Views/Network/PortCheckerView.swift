import SwiftUI

struct PortCheckerView: View {
    @StateObject private var scanner = PortScanner()
    @State private var host = ""
    @State private var selectedPreset = PortPresets.top20.id
    @FocusState private var hostFocused: Bool

    private var activePreset: PortPreset {
        PortPresets.all.first { $0.id == selectedPreset } ?? PortPresets.top20
    }

    var body: some View {
        ZStack {
            Color.cyberBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                inputSection
                if scanner.isScanning {
                    scanProgress
                }
                resultsList
            }
        }
        .navigationTitle("Port Checker")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var inputSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "scope")
                    .foregroundColor(.cyberGreen)
                TextField("target host or IP", text: $host)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .focused($hostFocused)
                    .submitLabel(.go)
                    .onSubmit { launch() }
            }
            .padding(12)
            .background(Color.cyberBackground)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cyberBorder, lineWidth: 1))

            presetPicker

            if let err = scanner.errorMessage {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            scanButton
        }
        .padding()
        .background(Color.cyberSurface)
    }

    private var presetPicker: some View {
        HStack(spacing: 8) {
            ForEach(PortPresets.all) { preset in
                Button {
                    HapticFeedback.statusChange()
                    selectedPreset = preset.id
                } label: {
                    Text(preset.label)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(selectedPreset == preset.id ? .black : .cyberGreen)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background(selectedPreset == preset.id ? Color.cyberGreen : Color.cyberBackground)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cyberGreen.opacity(0.3), lineWidth: 1))
                }
            }
        }
    }

    private var scanButton: some View {
        Group {
            if scanner.isScanning {
                Button(role: .destructive) {
                    HapticFeedback.statusChange()
                    scanner.stop()
                } label: {
                    Label("Stop Scan", systemImage: "stop.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.85))
                        .cornerRadius(10)
                }
            } else {
                Button {
                    launch()
                } label: {
                    Label("Scan \(activePreset.ports.count) Ports", systemImage: "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.cyberGreen)
                        .cornerRadius(10)
                        .neonGlow(.cyberGreen, radius: 6)
                }
            }
        }
    }

    private var scanProgress: some View {
        VStack(spacing: 4) {
            ProgressView(value: scanner.progress).tint(.cyberGreen)
            HStack {
                Text("Scanning \(scanner.target)…")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
                Text("\(Int(scanner.progress * 100))%")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.cyberGreen.opacity(0.7))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if scanner.results.isEmpty && !scanner.isScanning {
                    Text("$ awaiting target — select a preset and scan")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.cyberGreen.opacity(0.4))
                        .padding(.top, 30)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(scanner.results) { result in
                    resultRow(result)
                }
            }
            .padding()
        }
    }

    private func resultRow(_ result: PortResult) -> some View {
        HStack(spacing: 10) {
            Text(String(format: "%5d", result.port))
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(color(for: result.state))
            Text(result.service)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(result.state.rawValue)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(color(for: result.state))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color(for: result.state).opacity(0.15))
                .cornerRadius(4)
        }
        .padding(.vertical, 5)
    }

    private func color(for state: PortState) -> Color {
        switch state {
        case .open: return .cyberGreen
        case .closed: return .red
        case .filtered: return .orange
        }
    }

    private func launch() {
        hostFocused = false
        HapticFeedback.scanLaunch()
        scanner.start(host: host, ports: activePreset.ports)
    }
}
