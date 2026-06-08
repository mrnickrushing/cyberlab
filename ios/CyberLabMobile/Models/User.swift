import Foundation

struct User: Codable, Identifiable {
    let id: String
    let username: String
    let email: String
    let legalWarningAcknowledgedAt: String?
    let createdAt: String
}

struct AuthResponse: Codable {
    let token: String
    let refreshToken: String?
    let user: User
}

struct LoginRequest: Codable {
    let username: String
    let password: String
}

struct RegisterRequest: Codable {
    let username: String
    let email: String
    let password: String
}

struct RefreshTokenRequest: Codable {
    let refreshToken: String
}

struct RefreshTokenResponse: Codable {
    let token: String
}

struct RegisterDeviceRequest: Codable {
    let deviceToken: String
    let label: String?
}
