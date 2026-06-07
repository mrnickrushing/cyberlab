import SwiftUI

struct NetworkTopologyView: View {
    let hosts: [NetworkHost]

    var gateway: NetworkHost? { hosts.first(where: \.isGateway) }
    var otherHosts: [NetworkHost] { hosts.filter { !$0.isGateway } }

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) * 0.35
            let count = max(otherHosts.count, 1)

            ZStack {
                Color.cyberBackground.ignoresSafeArea()

                if hosts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "network.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.cyberGreen.opacity(0.3))
                        Text("No hosts to display")
                            .foregroundColor(.white.opacity(0.35))
                    }
                } else {
                    Canvas { ctx, size in
                        let centerPt = CGPoint(x: size.width / 2, y: size.height / 2)
                        let r = min(size.width, size.height) * 0.35

                        // Draw lines from center to each host
                        for (i, _) in otherHosts.enumerated() {
                            let angle = (2 * .pi * Double(i) / Double(count)) - (.pi / 2)
                            let end = CGPoint(
                                x: centerPt.x + r * cos(angle),
                                y: centerPt.y + r * sin(angle)
                            )
                            var path = Path()
                            path.move(to: centerPt)
                            path.addLine(to: end)
                            ctx.stroke(path, with: .color(.white.opacity(0.12)), lineWidth: 1)
                        }
                    }

                    // Gateway node in center
                    GatewayNode(host: gateway)
                        .position(center)

                    // Host nodes arranged in a circle
                    ForEach(Array(otherHosts.enumerated()), id: \.element.id) { i, host in
                        let angle = (2 * .pi * Double(i) / Double(count)) - (.pi / 2)
                        let pos = CGPoint(
                            x: center.x + radius * cos(angle),
                            y: center.y + radius * sin(angle)
                        )
                        HostNode(host: host)
                            .position(pos)
                    }
                }
            }
        }
        .background(Color.cyberBackground)
    }
}

struct GatewayNode: View {
    let host: NetworkHost?
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 52, height: 52)
                Circle()
                    .stroke(Color.blue.opacity(0.6), lineWidth: 2)
                    .frame(width: 52, height: 52)
                Image(systemName: "wifi.router.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.blue)
            }
            Text(host?.ipAddress ?? "Gateway")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.blue)
                .lineLimit(1)
        }
    }
}

struct HostNode: View {
    let host: NetworkHost
    var nodeColor: Color {
        host.isTrusted ? .cyberGreen : .orange
    }
    var iconName: String {
        host.isTrusted ? "checkmark.shield.fill" : "questionmark.circle.fill"
    }

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                Circle()
                    .fill(nodeColor.opacity(0.15))
                    .frame(width: 38, height: 38)
                Circle()
                    .stroke(nodeColor.opacity(0.5), lineWidth: 1.5)
                    .frame(width: 38, height: 38)
                Image(systemName: iconName)
                    .font(.system(size: 16))
                    .foregroundColor(nodeColor)
            }
            Text(host.ipAddress.components(separatedBy: ".").last ?? host.ipAddress)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(1)
        }
    }
}
