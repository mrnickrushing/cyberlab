import SwiftUI
import WebKit

struct KaliTerminalView: View {
    private let webViewStore = TerminalWebViewStore.shared
    private let relayURL = URL(string: "https://terminal.vitallity.org")!

    var body: some View {
        TerminalWebView(webView: webViewStore.webView, url: relayURL)
            .ignoresSafeArea()
            .background(Color.black)
            .onAppear {
                webViewStore.loadIfNeeded(url: relayURL)
            }
    }
}

@MainActor
private final class TerminalWebViewStore: ObservableObject {
    static let shared = TerminalWebViewStore()

    let webView: WKWebView
    private var loadedURL: URL?

    private init() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        self.webView = webView
    }

    func loadIfNeeded(url: URL) {
        guard loadedURL != url || webView.url == nil else { return }
        loadedURL = url
        webView.load(URLRequest(url: url))
    }
}

private struct TerminalWebView: UIViewRepresentable {
    let webView: WKWebView
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.url == nil {
            uiView.load(URLRequest(url: url))
        }
    }
}
