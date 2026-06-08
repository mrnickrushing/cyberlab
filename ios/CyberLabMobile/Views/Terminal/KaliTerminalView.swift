import SwiftUI
import WebKit

struct KaliTerminalView: View {
    @State private var isConnected = false
    @State private var hasConnectedOnce = false
    @State private var dotCount = 0

    private let relayURL = URL(string: "https://terminal.vitallity.org")!
    private let dotTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TerminalWebView(url: relayURL, isConnected: $isConnected)
                .ignoresSafeArea()

            if !isConnected {
                waitingOverlay
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.5), value: isConnected)
        .onChange(of: isConnected) { _, newValue in
            if newValue { hasConnectedOnce = true }
        }
        .onReceive(dotTimer) { _ in
            dotCount = (dotCount + 1) % 4
        }
    }

    private var waitingOverlay: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "terminal.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.cyberGreen)
                    .neonGlow(.cyberGreen, radius: 12)

                Text("K A L I   T E R M I N A L")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyberGreen)
                    .kerning(2)

                BlinkingCursor()

                Text("\(statusText)\(String(repeating: ".", count: dotCount))")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundColor(.cyberGreen.opacity(0.9))
                    .frame(minWidth: 280)

                Text("Start kali-server/main.py\non your Kali machine")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.cyberGreen.opacity(0.55))
                    .multilineTextAlignment(.center)

                PulsingDot()
                    .padding(.top, 8)

                Spacer()
            }
            .padding()
        }
    }

    private var statusText: String {
        hasConnectedOnce ? "Reconnecting" : "Waiting for Kali connection"
    }
}

private struct BlinkingCursor: View {
    @State private var visible = true

    var body: some View {
        Rectangle()
            .fill(Color.cyberGreen)
            .frame(width: 14, height: 26)
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    visible.toggle()
                }
            }
    }
}

private struct PulsingDot: View {
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(Color.cyberGreen)
            .frame(width: 12, height: 12)
            .scaleEffect(pulse ? 1.4 : 0.8)
            .opacity(pulse ? 0.4 : 1)
            .neonGlow(.cyberGreen, radius: 8)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    pulse.toggle()
                }
            }
    }
}

private struct TerminalWebView: UIViewRepresentable {
    let url: URL
    @Binding var isConnected: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isConnected: $isConnected)
    }

    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "terminalStatus")

        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black

        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        @Binding var isConnected: Bool

        init(isConnected: Binding<Bool>) {
            _isConnected = isConnected
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript(Self.statusMonitorJS)
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == "terminalStatus",
                  let body = message.body as? String else { return }
            let connected = body == "connected"
            DispatchQueue.main.async {
                self.isConnected = connected
            }
        }

        private static let statusMonitorJS = """
        const observer = new MutationObserver(function(mutations) {
            mutations.forEach(function(mutation) {
                if (mutation.target.id === 'status') {
                    const isConnected = mutation.target.classList.contains('connected');
                    window.webkit.messageHandlers.terminalStatus.postMessage(isConnected ? 'connected' : 'disconnected');
                }
            });
        });
        const statusEl = document.getElementById('status');
        if (statusEl) {
            observer.observe(statusEl, { attributes: true, attributeFilter: ['class'] });
            window.webkit.messageHandlers.terminalStatus.postMessage(
                statusEl.classList.contains('connected') ? 'connected' : 'disconnected'
            );
        }
        """
    }
}
