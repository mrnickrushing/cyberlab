import Foundation

// MARK: - HTTP Security Header Models

struct SecurityHeaderResult: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var present: Bool
    var value: String
    var explanation: String
}

struct HeaderScanResult: Equatable {
    var url: String
    var statusCode: Int
    var server: String
    var headers: [SecurityHeaderResult]

    var score: Int { headers.filter { $0.present }.count }
    var total: Int { headers.count }

    var grade: String {
        switch score {
        case 6...7: return "A"
        case 4...5: return "B"
        case 2...3: return "C"
        default:    return "F"
        }
    }
}

// MARK: - HTTP Headers Inspector
//
// Issues a HEAD request and grades the response for the presence of the
// industry-standard security response headers (HSTS, CSP, frame options, etc.).

@MainActor
final class HTTPHeadersInspector: ObservableObject {
    @Published var result: HeaderScanResult?
    @Published var isScanning = false
    @Published var errorMessage: String?

    private static let scored: [(key: String, label: String, why: String)] = [
        ("strict-transport-security", "HSTS", "Forces HTTPS, preventing protocol-downgrade attacks."),
        ("content-security-policy", "Content-Security-Policy", "Restricts script/resource origins to mitigate XSS."),
        ("x-frame-options", "X-Frame-Options", "Blocks clickjacking via framing."),
        ("x-content-type-options", "X-Content-Type-Options", "Stops MIME-type sniffing."),
        ("referrer-policy", "Referrer-Policy", "Controls how much referrer info leaks to other sites."),
        ("permissions-policy", "Permissions-Policy", "Restricts powerful browser features (camera, mic, etc.)."),
        ("x-xss-protection", "X-XSS-Protection", "Legacy reflected-XSS filter toggle.")
    ]

    func scan(url raw: String) {
        var input = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            errorMessage = "Enter a URL or host."
            return
        }
        if !input.lowercased().hasPrefix("http://") && !input.lowercased().hasPrefix("https://") {
            input = "https://\(input)"
        }
        guard let url = URL(string: input) else {
            errorMessage = "Invalid URL."
            return
        }

        isScanning = true
        errorMessage = nil
        result = nil

        Task {
            do {
                let scan = try await Self.fetch(url: url)
                self.result = scan
            } catch {
                self.errorMessage = "Request failed: \(error.localizedDescription)"
            }
            self.isScanning = false
        }
    }

    static func fetch(url: URL) async throws -> HeaderScanResult {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 20
        request.setValue("CyberLab/1.0", forHTTPHeaderField: "User-Agent")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        let lowered = Dictionary(uniqueKeysWithValues:
            http.allHeaderFields.compactMap { key, value -> (String, String)? in
                guard let k = key as? String, let v = value as? String else { return nil }
                return (k.lowercased(), v)
            }
        )

        let results = scored.map { entry -> SecurityHeaderResult in
            let value = lowered[entry.key]
            return SecurityHeaderResult(
                name: entry.label,
                present: value != nil,
                value: value ?? "—",
                explanation: entry.why
            )
        }

        return HeaderScanResult(
            url: url.absoluteString,
            statusCode: http.statusCode,
            server: lowered["server"] ?? "—",
            headers: results
        )
    }
}
