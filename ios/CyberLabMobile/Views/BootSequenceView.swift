import SwiftUI

/// Terminal-style "INITIALIZING…" boot sequence shown briefly on cold launch.
struct BootSequenceView: View {
    let onComplete: () -> Void

    @State private var visibleCount = 0

    private let bootLines = [
        "INITIALIZING CYBERLAB CONSOLE...",
        "ESTABLISHING SECURE CHANNEL...",
        "LOADING OPERATOR PROFILE...",
        "READY."
    ]

    var body: some View {
        ZStack {
            Color.cyberBackground.ignoresSafeArea()
                .scanlines(beam: true, beamColor: .cyberGreen)

            VStack(alignment: .leading, spacing: 8) {
                Spacer()
                ForEach(0..<visibleCount, id: \.self) { index in
                    HStack(alignment: .top, spacing: 8) {
                        Text(">")
                            .foregroundColor(.cyberGreen.opacity(0.6))
                        Text(bootLines[index])
                            .foregroundColor(index == bootLines.count - 1 ? .cyberGreen : .white.opacity(0.7))
                            .neonGlow(.cyberGreen, radius: index == bootLines.count - 1 ? 6 : 0)
                    }
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .transition(.opacity)
                }
                Spacer()
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task {
            for index in bootLines.indices {
                try? await Task.sleep(nanoseconds: 280_000_000)
                withAnimation(.easeOut(duration: 0.18)) { visibleCount = index + 1 }
            }
            try? await Task.sleep(nanoseconds: 420_000_000)
            onComplete()
        }
    }
}
