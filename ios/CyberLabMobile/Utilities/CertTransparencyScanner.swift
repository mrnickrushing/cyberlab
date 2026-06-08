import Foundation

// MARK: - Cert Transparency Models

struct CTEntry: Identifiable, Equatable {
    let id = UUID()
    var subdomain: String
    var issuer: String
    var notBefore: String
    var notAfter: String
}

private struct CrtShRecord: Decodable {
    let name_value: String?
    let issuer_name: String?
    let not_before: String?
    let not_after: String?
}

// MARK: - Cert Transparency Scanner
//
// Queries crt.sh's public certificate-transparency log search to enumerate
// subdomains that have ever had a TLS certificate issued. crt.sh returns one
// JSON object per logged certificate; a single name_value field may contain
// several newline-separated SANs, so we split and deduplicate.

@MainActor
final class CertTransparencyScanner: ObservableObject {
    @Published var entries: [CTEntry] = []
    @Published var isScanning = false
    @Published var errorMessage: String?

    var subdomainCount: Int {
        Set(entries.map { $0.subdomain.lowercased() }).count
    }

    func scan(domain raw: String) {
        let domain = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .lowercased()
        guard !domain.isEmpty else {
            errorMessage = "Enter a domain (e.g. example.com)"
            return
        }

        isScanning = true
        errorMessage = nil
        entries = []

        Task {
            do {
                let result = try await Self.fetch(domain: domain)
                self.entries = result
                if result.isEmpty {
                    self.errorMessage = "No certificate-transparency records found for \(domain)."
                }
            } catch {
                self.errorMessage = "Lookup failed: \(error.localizedDescription)"
            }
            self.isScanning = false
        }
    }

    static func fetch(domain: String) async throws -> [CTEntry] {
        let encoded = "%25.\(domain)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "%25.\(domain)"
        guard let url = URL(string: "https://crt.sh/?q=\(encoded)&output=json") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("CyberLab/1.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        let records = try JSONDecoder().decode([CrtShRecord].self, from: data)

        var seen = Set<String>()
        var out: [CTEntry] = []
        for record in records {
            let names = (record.name_value ?? "")
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            for name in names where !name.isEmpty {
                let key = "\(name)|\(record.issuer_name ?? "")"
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                out.append(CTEntry(
                    subdomain: name,
                    issuer: Self.shortIssuer(record.issuer_name ?? "Unknown"),
                    notBefore: Self.shortDate(record.not_before),
                    notAfter: Self.shortDate(record.not_after)
                ))
            }
        }
        return out.sorted { $0.subdomain < $1.subdomain }
    }

    private static func shortIssuer(_ raw: String) -> String {
        if let range = raw.range(of: "O=") {
            let tail = raw[range.upperBound...]
            let value = tail.prefix(while: { $0 != "," })
            return String(value)
        }
        return raw
    }

    private static func shortDate(_ raw: String?) -> String {
        guard let raw, raw.count >= 10 else { return raw ?? "—" }
        return String(raw.prefix(10))
    }
}
