import SwiftUI
import UniformTypeIdentifiers

/// A styled, shareable "intel card" image for a single finding.
struct IntelCardView: View {
    let finding: Finding
    var targetName: String?
    var targetAddress: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 16))
                    .foregroundColor(.cyberGreen)
                Text("CYBERLAB INTEL")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(.cyberGreen)
                    .kerning(2)
                Spacer()
                Text(finding.severity.label.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(finding.severity.color)
                    .cornerRadius(6)
            }

            Rectangle().fill(Color.cyberGreen.opacity(0.4)).frame(height: 1)

            // Title
            Text(finding.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)

            // Meta grid
            VStack(alignment: .leading, spacing: 8) {
                if let cve = finding.cveId {
                    intelRow("CVE", cve, .cyberCyan)
                }
                if let cvss = finding.cvssScore {
                    intelRow("CVSS", String(format: "%.1f", cvss), finding.severity.color)
                }
                if let name = targetName {
                    intelRow("TARGET", name, .white)
                }
                if let addr = targetAddress {
                    intelRow("ADDRESS", addr, .cyberGreen)
                }
                intelRow("STATUS", finding.status.label, .white.opacity(0.8))
                intelRow("LOGGED", finding.createdAt.formattedFullDate, .white.opacity(0.6))
            }

            Spacer(minLength: 0)

            Rectangle().fill(Color.cyberBorder).frame(height: 1)

            // Watermark
            HStack {
                Image(systemName: "lock.shield")
                    .font(.system(size: 11))
                    .foregroundColor(.cyberGreen.opacity(0.6))
                Text("CyberLab Mobile · Authorized Lab Use Only")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
            }
        }
        .padding(24)
        .frame(width: 360, height: 480, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [Color.cyberSurface, Color.cyberBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.cyberGreen.opacity(0.35), lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func intelRow(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 78, alignment: .leading)
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Share button

/// Renders an `IntelCardView` to a `UIImage` and presents a native share sheet.
struct IntelCardShareButton: View {
    let finding: Finding
    var targetName: String?
    var targetAddress: String?

    @State private var rendered: IntelCardImage?

    var body: some View {
        Group {
            if let rendered {
                ShareLink(
                    item: rendered,
                    preview: SharePreview("CyberLab Intel: \(finding.title)", image: rendered.image)
                ) {
                    shareLabel
                }
            } else {
                Button { render() } label: { shareLabel }
            }
        }
        .onAppear { render() }
    }

    private var shareLabel: some View {
        Label("Share Intel Card", systemImage: "square.and.arrow.up")
            .foregroundColor(.cyberGreen)
    }

    @MainActor
    private func render() {
        let renderer = ImageRenderer(content:
            IntelCardView(finding: finding, targetName: targetName, targetAddress: targetAddress)
        )
        renderer.scale = 3.0
        if let uiImage = renderer.uiImage {
            rendered = IntelCardImage(uiImage: uiImage)
        }
    }
}

/// `Transferable` wrapper so the rendered card can be shared as a PNG.
struct IntelCardImage: Transferable {
    let uiImage: UIImage
    var image: Image { Image(uiImage: uiImage) }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { card in
            card.uiImage.pngData() ?? Data()
        }
    }
}
