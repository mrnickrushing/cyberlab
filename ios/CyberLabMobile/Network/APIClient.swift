import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case notFound
    case serverError(Int, String?)
    case decodingError(Error)
    case networkError(Error)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL"
        case .unauthorized: return "Authentication required. Please log in again."
        case .notFound: return "Resource not found"
        case .serverError(let code, let msg): return msg ?? "Server error (\(code))"
        case .decodingError(let e): return "Failed to parse response: \(e.localizedDescription)"
        case .networkError(let e): return "Network error: \(e.localizedDescription)"
        case .noData: return "No data received"
        }
    }
}

struct APIErrorBody: Codable {
    let error: String?
    let message: String?
}

@MainActor
class APIClient: ObservableObject {
    static let shared = APIClient()

    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)

        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    var baseURL: String {
        KeychainManager.load(.serverURL) ?? "https://api-server-production-df35.up.railway.app/api"
    }

    func setServerURL(_ url: String) {
        KeychainManager.save(url, for: .serverURL)
    }

    // MARK: - Core Request

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        guard var urlComponents = URLComponents(string: "\(baseURL)\(endpoint.path)") else {
            throw APIError.invalidURL
        }
        if let queryItems = endpoint.queryItems {
            urlComponents.queryItems = queryItems
        }
        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Attach JWT token
        if let token = KeychainManager.load(.accessToken) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Encode body
        if let body = endpoint.body {
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.noData
            }

            switch httpResponse.statusCode {
            case 200...299:
                if data.isEmpty, T.self == EmptyResponse.self {
                    return EmptyResponse() as! T
                }
                do {
                    return try decoder.decode(T.self, from: data)
                } catch {
                    throw APIError.decodingError(error)
                }
            case 401:
                throw APIError.unauthorized
            case 404:
                throw APIError.notFound
            default:
                let errorBody = try? decoder.decode(APIErrorBody.self, from: data)
                throw APIError.serverError(
                    httpResponse.statusCode,
                    errorBody?.error ?? errorBody?.message
                )
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    // Void response helper
    func requestVoid(_ endpoint: APIEndpoint) async throws {
        let _: EmptyResponse = try await request(endpoint)
    }
}

// Helpers for type erasure
struct EmptyResponse: Codable {}

struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init(_ encodable: Encodable) {
        _encode = encodable.encode
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
