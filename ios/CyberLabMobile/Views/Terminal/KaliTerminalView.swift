import SwiftUI
import WebKit

struct KaliTerminalView: View {
    private let relayURL = URL(string: "https://terminal.vitallity.org")!

    var body: some View {
        TerminalWebView(url: relayURL)
            .ignoresSafeArea()
            .background(Color.black)
    }
}

private struct TerminalWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black

        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
