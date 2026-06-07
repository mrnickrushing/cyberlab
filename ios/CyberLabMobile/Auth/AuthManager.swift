import Foundation
import Combine

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var error: String?
    @Published var legalAcknowledged = false

    private let client = APIClient.shared

    private init() {
        // Restore session on launch
        if KeychainManager.load(.accessToken) != nil {
            isAuthenticated = true
            legalAcknowledged = UserDefaults.standard.bool(forKey: "cyberlab_legal_ack")
            Task { await fetchCurrentUser() }
        }
    }

    func login(username: String, password: String) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }

        let req = LoginRequest(username: username, password: password)
        let response: AuthResponse = try await client.request(Endpoints.login(req))

        KeychainManager.save(response.token, for: .accessToken)
        if let refresh = response.refreshToken {
            KeychainManager.save(refresh, for: .refreshToken)
        }
        currentUser = response.user
        legalAcknowledged = response.user.legalWarningAcknowledgedAt != nil
        isAuthenticated = true
    }

    func register(username: String, email: String, password: String) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }

        let req = RegisterRequest(username: username, email: email, password: password)
        let response: AuthResponse = try await client.request(Endpoints.register(req))

        KeychainManager.save(response.token, for: .accessToken)
        if let refresh = response.refreshToken {
            KeychainManager.save(refresh, for: .refreshToken)
        }
        currentUser = response.user
        legalAcknowledged = false
        isAuthenticated = true
    }

    func logout() {
        Task {
            try? await client.requestVoid(Endpoints.logout)
        }
        KeychainManager.deleteAll()
        currentUser = nil
        isAuthenticated = false
        legalAcknowledged = false
    }

    func acknowledgeLegal() async throws {
        try await client.requestVoid(Endpoints.legalAcknowledge)
        legalAcknowledged = true
        UserDefaults.standard.set(true, forKey: "cyberlab_legal_ack")
    }

    func fetchCurrentUser() async {
        do {
            let user: User = try await client.request(Endpoints.me)
            currentUser = user
            legalAcknowledged = user.legalWarningAcknowledgedAt != nil
        } catch APIError.unauthorized {
            await tryTokenRefresh()
        } catch {
            // Silently fail — user stays authenticated with cached data
        }
    }

    private func tryTokenRefresh() async {
        guard let refreshToken = KeychainManager.load(.refreshToken) else {
            logout()
            return
        }
        do {
            let req = RefreshTokenRequest(refreshToken: refreshToken)
            let response: RefreshTokenResponse = try await client.request(Endpoints.refresh(req))
            KeychainManager.save(response.token, for: .accessToken)
            await fetchCurrentUser()
        } catch {
            logout()
        }
    }
}
