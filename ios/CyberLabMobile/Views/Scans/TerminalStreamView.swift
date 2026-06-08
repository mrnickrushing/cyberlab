import SwiftUI

/// `tail -f`-style live console for an in-progress (or completed) scan.
///
/// Polls the scan's raw output every 2s while the job is active, appending new
/// lines as they arrive and auto-scrolling to the bottom. A blinking cursor is
/// shown after the last line while the scan is still running.
struct TerminalStreamView: View {
    let scanId: String
    let tool: String
    var initialRawOutput: String = ""

    @Environment(\.dismiss) private var dismiss
    @State private var lines: [TerminalLine] = []
    @State private var fullOutput = ""
    @State private var status: ScanStatus = .running
    @State private var cursorOn = true
    @State private var pollTimer: Timer?
    @State private var blinkTimer: Timer?
    private let client = APIClient.shared

    private var isRunning: Bool { status == .pending || status == .running }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 1) {
                            headerLine
                            ForEach(lines) { line in
                                Text(line.text.isEmpty ? " " : line.text)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.cyberGreen.opacity(0.92))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(line.id)
                            }
                            cursorLine.id("cursor")
                        }
                        .padding(12)
                    }
                    .onChange(of: lines.count) { _, _ in
                        withAnimation(.linear(duration: 0.15)) {
                            proxy.scrollTo("cursor", anchor: .bottom)
                        }
                    }
                }
            }
            .navigationTitle("Live Terminal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundColor(.cyberGreen)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 14) {
                        Button {
                            UIPasteboard.general.string = fullOutput
                            HapticFeedback.statusChange()
                        } label: {
                            Image(systemName: "doc.on.doc").foregroundColor(.cyberGreen)
                        }
                        ShareLink(item: fullOutput) {
                            Image(systemName: "square.and.arrow.up").foregroundColor(.cyberGreen)
                        }
                    }
                }
            }
        }
        .onAppear {
            if !initialRawOutput.isEmpty { applyOutput(initialRawOutput) }
            startBlink()
            startPolling()
            Task { await poll() }
        }
        .onDisappear { pollTimer?.invalidate(); pollTimer = nil; blinkTimer?.invalidate(); blinkTimer = nil }
    }

    private var headerLine: some View {
        Text("$ cyberlab run --tool \(tool) --follow")
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundColor(.cyberGreen)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 4)
    }

    @ViewBuilder
    private var cursorLine: some View {
        if isRunning {
            Text("█")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.cyberGreen)
                .opacity(cursorOn ? 1 : 0)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text("[process exited — status: \(status.label)]")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func startBlink() {
        blinkTimer?.invalidate()
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true) { _ in
            cursorOn.toggle()
        }
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            Task { await poll() }
        }
    }

    @MainActor
    private func poll() async {
        if let job: ScanJob = try? await client.request(Endpoints.scan(scanId)) {
            status = job.status
        }
        if let result: ScanResult = try? await client.request(Endpoints.scanResults(scanId)),
           let raw = result.rawOutput {
            applyOutput(raw)
        }
        if !isRunning { pollTimer?.invalidate(); pollTimer = nil }
    }

    /// Replace the displayed lines with the newest output, preserving identity so
    /// only genuinely new lines animate in.
    private func applyOutput(_ raw: String) {
        guard raw != fullOutput else { return }
        fullOutput = raw
        let split = raw.components(separatedBy: "\n")
        lines = split.enumerated().map { TerminalLine(id: $0.offset, text: $0.element) }
    }
}

private struct TerminalLine: Identifiable {
    let id: Int
    let text: String
}
