import SwiftUI

// MARK: - Color Extensions

extension Color {
    static let cyberGreen = Color(red: 0.063, green: 0.725, blue: 0.506)
    static let cyberBackground = Color(red: 0.047, green: 0.063, blue: 0.082)
    static let cyberSurface = Color(red: 0.071, green: 0.098, blue: 0.133)
    static let cyberBorder = Color(red: 0.137, green: 0.188, blue: 0.251)

    // Secondary neon accents — duotone cyan/magenta pairing for cyberpunk contrast
    static let cyberMagenta = Color(red: 1.0, green: 0.157, blue: 0.635)
    static let cyberCyan = Color(red: 0.122, green: 0.890, blue: 1.0)

    // Shared severity palette (Critical/High/Medium/Low/Info) — single source of truth
    // so FindingSeverity and RiskLevel render identically.
    static let severityCritical = Color(red: 1.0, green: 0.231, blue: 0.188)
    static let severityHigh = Color(red: 1.0, green: 0.584, blue: 0.0)
    static let severityMedium = Color(red: 1.0, green: 0.8, blue: 0.0)
    static let severityLow = Color(red: 0.204, green: 0.780, blue: 0.349)
    static let severityInfo = Color(red: 0.557, green: 0.557, blue: 0.576)
}

extension FindingSeverity {
    var color: Color {
        switch self {
        case .critical: return .severityCritical
        case .high: return .severityHigh
        case .medium: return .severityMedium
        case .low: return .severityLow
        case .info: return .severityInfo
        }
    }

    var label: String { rawValue.capitalized }
}

extension FindingStatus {
    var label: String {
        switch self {
        case .open: return "Open"
        case .fixed: return "Fixed"
        case .acceptedRisk: return "Accepted Risk"
        case .falsePositive: return "False Positive"
        }
    }
    var color: Color {
        switch self {
        case .open: return .red
        case .fixed: return .green
        case .acceptedRisk: return .orange
        case .falsePositive: return .gray
        }
    }
}

extension ScanStatus {
    var label: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .pending: return .gray
        case .running: return .cyberGreen
        case .completed: return .blue
        case .failed: return .red
        case .cancelled: return .orange
        }
    }
    var isActive: Bool { self == .pending || self == .running }
}

extension AuthorizationStatus {
    var label: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .authorized: return .cyberGreen
        case .unauthorized: return .red
        case .pending: return .orange
        }
    }
}

extension RiskLevel {
    var label: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .critical: return .severityCritical
        case .high: return .severityHigh
        case .medium: return .severityMedium
        case .low: return .severityLow
        case .info: return .severityInfo
        }
    }
}

extension TargetType {
    var label: String {
        switch self {
        case .ip: return "IP"
        case .domain: return "Domain"
        case .subnet: return "Subnet"
        case .webapp: return "Web App"
        }
    }
    var systemImage: String {
        switch self {
        case .ip: return "server.rack"
        case .domain: return "globe"
        case .subnet: return "network"
        case .webapp: return "safari"
        }
    }
}

// MARK: - Date Formatting

extension String {
    var formattedDate: String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: self) {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: date, relativeTo: Date())
        }
        return self
    }

    var relativeTime: String { formattedDate }

    var formattedFullDate: String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: self) {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        return self
    }
}

// MARK: - View Modifiers

struct CyberCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.cyberSurface)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.cyberBorder, lineWidth: 1)
            )
    }
}

extension View {
    func cyberCard() -> some View {
        modifier(CyberCardModifier())
    }
}

// MARK: - Cyberpunk Visual Effects

/// Layered neon shadow glow — used on primary actions, live indicators, and critical badges.
struct NeonGlowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(radius > 0 ? 0.75 : 0), radius: radius)
            .shadow(color: color.opacity(radius > 0 ? 0.4 : 0), radius: radius * 2.2)
    }
}

extension View {
    func neonGlow(_ color: Color = .cyberGreen, radius: CGFloat = 6) -> some View {
        modifier(NeonGlowModifier(color: color, radius: radius))
    }
}

/// Slow breathing glow for "live" elements (running scans, active schedules).
struct PulsingGlowModifier: ViewModifier {
    let color: Color
    @State private var pulsing = false
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(pulsing ? 0.9 : 0.35), radius: pulsing ? 9 : 3)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
            }
    }
}

extension View {
    func pulsingGlow(_ color: Color = .cyberGreen) -> some View {
        modifier(PulsingGlowModifier(color: color))
    }
}

/// Periodic RGB-split jitter — a brief "glitch" pulse for critical/alert text.
struct GlitchModifier: ViewModifier {
    @State private var active = false
    func body(content: Content) -> some View {
        content
            .overlay(
                content
                    .foregroundColor(.cyberMagenta)
                    .offset(x: active ? -2.5 : 0)
                    .opacity(active ? 0.6 : 0)
                    .blendMode(.screen)
            )
            .overlay(
                content
                    .foregroundColor(.cyberCyan)
                    .offset(x: active ? 2.5 : 0)
                    .opacity(active ? 0.6 : 0)
                    .blendMode(.screen)
            )
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 3_400_000_000)
                    withAnimation(.easeInOut(duration: 0.05)) { active = true }
                    try? await Task.sleep(nanoseconds: 90_000_000)
                    withAnimation(.easeInOut(duration: 0.12)) { active = false }
                }
            }
    }
}

extension View {
    func glitchEffect() -> some View {
        modifier(GlitchModifier())
    }
}

/// Faint horizontal scanline texture — CRT/HUD overlay for hero screens.
struct ScanlineOverlay: View {
    var lineOpacity: Double = 0.045
    var spacing: CGFloat = 4
    var body: some View {
        GeometryReader { geo in
            Path { path in
                var y: CGFloat = 0
                while y < geo.size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    y += spacing
                }
            }
            .stroke(Color.white.opacity(lineOpacity), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

/// Slow vertical sweep beam — paired with scanlines on the login screen.
struct ScanBeamOverlay: View {
    var color: Color = .cyberGreen
    @State private var offset: CGFloat = -0.4
    var body: some View {
        GeometryReader { geo in
            LinearGradient(colors: [.clear, color.opacity(0.10), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: geo.size.height * 0.3)
                .offset(y: offset * geo.size.height)
                .onAppear {
                    withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) {
                        offset = 1.4
                    }
                }
        }
        .allowsHitTesting(false)
    }
}

extension View {
    /// Adds a subtle CRT scanline texture, optionally with a slow sweeping scan beam.
    func scanlines(beam: Bool = false, beamColor: Color = .cyberGreen) -> some View {
        overlay(ScanlineOverlay())
            .overlay(beam ? AnyView(ScanBeamOverlay(color: beamColor)) : AnyView(EmptyView()))
    }
}

/// HUD-style targeting-reticle corner brackets, drawn as an overlay stroke.
struct HUDCornerBrackets: Shape {
    var length: CGFloat = 14
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + length))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + length, y: rect.minY))

        path.move(to: CGPoint(x: rect.maxX - length, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + length))

        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - length))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - length, y: rect.maxY))

        path.move(to: CGPoint(x: rect.minX + length, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - length))
        return path
    }
}

extension View {
    func hudFrame(color: Color = .cyberGreen, length: CGFloat = 14, lineWidth: CGFloat = 2) -> some View {
        overlay(HUDCornerBrackets(length: length).stroke(color, lineWidth: lineWidth))
    }
}

// MARK: - Badge View

struct SeverityBadge: View {
    let severity: FindingSeverity

    private var label: some View {
        Text(severity.label)
            .font(.caption2.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(severity.color)
            .cornerRadius(4)
            .neonGlow(severity.color, radius: severity == .critical ? 5 : 0)
    }

    var body: some View {
        if severity == .critical {
            label.glitchEffect()
        } else {
            label
        }
    }
}

struct StatusBadge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color)
            .cornerRadius(4)
    }
}

// ─── KEV Badge ─────────────────────────────────────────────────────────────────
// Shown on any finding whose CVE appears in the CISA Known Exploited
// Vulnerabilities catalog.

struct KEVBadge: View {
    @State private var glowing = false

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 8, weight: .bold))
            Text("ACTIVELY EXPLOITED")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .kerning(0.3)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            LinearGradient(
                colors: [Color.severityCritical, Color.severityCritical.opacity(0.75)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(4)
        .shadow(color: .severityCritical.opacity(glowing ? 0.85 : 0.3), radius: glowing ? 7 : 3)
        .glitchEffect()
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                glowing = true
            }
        }
    }
}

// ─── KEV Detail Card ───────────────────────────────────────────────────────────

struct KEVDetailCard: View {
    let entry: KEVEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "shield.lefthalf.filled.trianglebadge.exclamationmark")
                    .font(.system(size: 16))
                    .foregroundColor(.severityCritical)
                    .neonGlow(.severityCritical, radius: 5)
                VStack(alignment: .leading, spacing: 2) {
                    Text("CISA KEV Catalog")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.severityCritical)
                    Text("This vulnerability is actively exploited in the wild")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
            }

            Divider().background(Color.severityCritical.opacity(0.3))

            Group {
                kevKV("Vendor",    entry.vendorProject)
                kevKV("Product",   entry.product)
                kevKV("Name",      entry.vulnerabilityName)
                kevKV("Added",     entry.dateAdded)
                if let due = entry.dueDate { kevKV("Due Date", due) }
            }

            // Required action
            VStack(alignment: .leading, spacing: 4) {
                Text("REQUIRED ACTION")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.severityCritical.opacity(0.8))
                Text(entry.requiredAction)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color.severityCritical.opacity(0.12), Color.cyberSurface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.severityCritical.opacity(0.45), lineWidth: 1)
        )
        .hudFrame(color: .severityCritical.opacity(0.5), length: 12)
    }

    private func kevKV(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
                .textSelection(.enabled)
        }
    }
}
