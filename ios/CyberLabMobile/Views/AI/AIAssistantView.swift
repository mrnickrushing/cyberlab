import SwiftUI

struct AIAssistantView: View {
    @State var mode: AIMode = .general
    @State var prefillContext: AIChatContext? = nil
    @State var prefillMessage: String = ""

    @State private var messages: [AIChatMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading = false
    @State private var isConfigured: Bool? = nil
    @State private var error: String?
    @FocusState private var inputFocused: Bool
    private let client = APIClient.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cyberBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    modeBar
                    if let ctx = prefillContext {
                        ContextBanner(context: ctx, mode: mode) { prefillContext = nil }
                    }
                    if isConfigured == false {
                        unconfiguredBanner
                    }
                    chatList
                    inputBar
                }
            }
            .navigationTitle("AI Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation { messages.removeAll(); error = nil }
                    } label: {
                        Image(systemName: "trash").foregroundColor(.white.opacity(0.4))
                    }
                    .disabled(messages.isEmpty)
                }
            }
        }
        .task { await checkStatus(); injectPrefill() }
    }

    // ─── Mode bar ─────────────────────────────────────────────────────────────

    private var modeBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AIMode.allCases) { m in
                    Button {
                        withAnimation { mode = m }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: m.icon).font(.system(size: 11))
                            Text(m.label).font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(mode == m ? .black : .white.opacity(0.6))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(mode == m ? Color.cyberMagenta : Color.cyberSurface)
                        .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .background(Color.cyberBackground)
    }

    // ─── Unconfigured banner ───────────────────────────────────────────────────

    private var unconfiguredBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("OPENAI_API_KEY not configured")
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(.orange)
                Text("Set OPENAI_API_KEY on your Railway API server to enable AI.")
                    .font(.system(size: 11)).foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color.orange.opacity(0.3)), alignment: .bottom)
    }

    // ─── Chat list ────────────────────────────────────────────────────────────

    private var chatList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if messages.isEmpty {
                        welcomeCard
                    }
                    ForEach(messages) { msg in
                        ChatBubble(message: msg)
                            .id(msg.id)
                    }
                    if isLoading {
                        TypingIndicator()
                    }
                    if let error {
                        ErrorBubble(message: error)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)
            }
            .onChange(of: messages.count) { _ in
                withAnimation { proxy.scrollTo("bottom") }
            }
            .onChange(of: isLoading) { _ in
                withAnimation { proxy.scrollTo("bottom") }
            }
        }
    }

    private var welcomeCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundColor(.cyberMagenta.opacity(0.7))
                .neonGlow(.cyberMagenta, radius: 10)
            Text("CyberLab AI")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            Text(mode.description)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(suggestionsFor(mode), id: \.self) { suggestion in
                    Button { inputText = suggestion } label: {
                        HStack {
                            Image(systemName: "chevron.right.circle").font(.system(size: 13)).foregroundColor(.cyberMagenta)
                            Text(suggestion).font(.system(size: 13)).foregroundColor(.white.opacity(0.8))
                            Spacer()
                        }
                        .padding(10)
                        .background(Color.cyberSurface)
                        .cornerRadius(8)
                    }
                }
            }
            Text("⚠️ Authorized lab use only — never scan systems you don't own.")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.3))
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }

    // ─── Input bar ────────────────────────────────────────────────────────────

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField(mode.description, text: $inputText, axis: .vertical)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .padding(12)
                .background(Color.cyberSurface)
                .cornerRadius(10)
                .lineLimit(1...5)
                .focused($inputFocused)
                .onSubmit { sendIfReady() }

            Button {
                sendIfReady()
            } label: {
                Image(systemName: isLoading ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? .white.opacity(0.2) : .cyberMagenta)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.cyberBackground.shadow(radius: 4))
    }

    // ─── Logic ────────────────────────────────────────────────────────────────

    private func sendIfReady() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !isLoading else { return }
        inputText = ""
        inputFocused = false
        Task { await send(text: text) }
    }

    private func send(text: String) async {
        error = nil
        let userMsg = AIChatMessage(role: .user, content: text)
        messages.append(userMsg)
        isLoading = true

        let history: [AIChatHistoryTurn] = messages.dropLast().suffix(10).map {
            AIChatHistoryTurn(role: $0.role.rawValue, content: $0.content)
        }

        let req = AIChatRequest(
            message: text,
            mode: mode.rawValue,
            context: prefillContext,
            history: history.isEmpty ? nil : history
        )

        do {
            let response: AIChatResponse = try await client.request(Endpoints.aiChat(req))
            messages.append(AIChatMessage(role: .assistant, content: response.reply))
            // Only inject context once
            prefillContext = nil
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }

    private func checkStatus() async {
        if let status: AIStatus = try? await client.request(Endpoints.aiStatus) {
            isConfigured = status.configured
        }
    }

    private func injectPrefill() {
        if !prefillMessage.isEmpty {
            inputText = prefillMessage
        }
    }

    private func suggestionsFor(_ mode: AIMode) -> [String] {
        switch mode {
        case .general:     return ["What is a CVSS score?", "Explain the difference between nmap and masscan", "What is OSINT and how is it used ethically?"]
        case .explain:     return ["What makes a critical finding dangerous?", "How do I interpret a CVSS 9.8 score?", "What is a TOR exit node risk?"]
        case .summarize:   return ["Summarize the key risks for my current target", "What should I prioritize fixing first?"]
        case .remediation: return ["How do I harden an SSH server?", "What's the fastest way to fix an open MongoDB port?"]
        case .study:       return ["Explain how nmap port scanning works", "What is nuclei and how do templates work?", "Walk me through a basic web assessment workflow"]
        }
    }
}

// ─── Chat bubble ──────────────────────────────────────────────────────────────

struct ChatBubble: View {
    let message: AIChatMessage
    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 48) }
            if !isUser {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 14))
                    .foregroundColor(.cyberMagenta)
                    .frame(width: 28, height: 28)
                    .background(Color.cyberSurface)
                    .clipShape(Circle())
            }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(size: 14))
                    .foregroundColor(isUser ? .black : .white)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(isUser ? Color.cyberGreen : Color.cyberSurface)
                    .overlay {
                        if !isUser {
                            RoundedCorner(radius: 16, corners: [.topLeft, .topRight, .bottomRight])
                                .stroke(Color.cyberMagenta.opacity(0.25), lineWidth: 1)
                        }
                    }
                    .cornerRadius(16, corners: isUser
                        ? [.topLeft, .topRight, .bottomLeft]
                        : [.topLeft, .topRight, .bottomRight])
                    .textSelection(.enabled)
                Text(message.timestamp, style: .time)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.25))
            }
            if isUser {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.cyberGreen.opacity(0.6))
            }
            if !isUser { Spacer(minLength: 48) }
        }
    }
}

// ─── Typing indicator ─────────────────────────────────────────────────────────

struct TypingIndicator: View {
    @State private var phase = 0
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 14)).foregroundColor(.cyberMagenta)
                .frame(width: 28, height: 28).background(Color.cyberSurface).clipShape(Circle())
            HStack(spacing: 5) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.cyberMagenta.opacity(phase == i ? 1 : 0.3))
                        .frame(width: 7, height: 7)
                        .scaleEffect(phase == i ? 1.2 : 1)
                        .animation(.easeInOut(duration: 0.3), value: phase)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Color.cyberSurface)
            .cornerRadius(16, corners: [.topLeft, .topRight, .bottomRight])
            Spacer(minLength: 48)
        }
        .onReceive(timer) { _ in phase = (phase + 1) % 3 }
    }
}

// ─── Error bubble ─────────────────────────────────────────────────────────────

struct ErrorBubble: View {
    let message: String
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
            Text(message).font(.system(size: 12)).foregroundColor(.red.opacity(0.9))
        }
        .padding(10)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
}

// ─── Context banner ───────────────────────────────────────────────────────────

struct ContextBanner: View {
    let context: AIChatContext
    let mode: AIMode
    let onDismiss: () -> Void

    var contextLabel: String {
        if let title = context.findingTitle { return "Finding: \(title)" }
        if let name = context.reportTargetName { return "Report: \(name)" }
        return "Context loaded"
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: mode.icon).font(.system(size: 13)).foregroundColor(.cyberMagenta)
            Text(contextLabel)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill").foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(Color.cyberMagenta.opacity(0.12))
        .overlay(Rectangle().frame(height: 1).foregroundColor(.cyberMagenta.opacity(0.3)), alignment: .bottom)
    }
}

// ─── Corner radius helper ─────────────────────────────────────────────────────

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
