import Foundation

// MARK: - WHOIS Models

struct WHOISResult: Equatable {
    var raw: String
    var registrar: String?
    var created: String?
    var expires: String?
    var nameservers: [String]
}

// MARK: - WHOIS Lookup
//
// Retrieves raw WHOIS text for a domain via HackerTarget and extracts the most
// commonly referenced fields for a highlight summary.

@MainActor
final class WHOISLookup: ObservableObject {
    @Published var result: WHOISResult?
    @Published var isScanning = false
    @Published var errorMessage: String?

    func lookup(domain raw: String) {
        let domain = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .lowercased()
        guard !domain.isEmpty else {
            errorMessage = "Enter a domain."
            return
        }

        isScanning = true
        errorMessage = nil
        result = nil

        Task {
            do {
                let text = try await PassiveDNSScanner.fetchText(path: "whois", query: domain)
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.errorMessage = "No WHOIS data returned for \(domain)."
                } else {
                    self.result = Self.parse(text)
                }
            } catch {
                self.errorMessage = "Lookup failed: \(error.localizedDescription)"
            }
            self.isScanning = false
        }
    }

    static func parse(_ text: String) -> WHOISResult {
        var registrar: String?
        var created: String?
        var expires: String?
        var nameservers: [String] = []

        for line in text.split(separator: "\n") {
            let lower = line.lowercased()
            let value = line.split(separator: ":", maxSplits: 1).count == 2
                ? line.split(separator: ":", maxSplits: 1)[1].trimmingCharacters(in: .whitespaces)
                : ""
            if registrar == nil, lower.contains("registrar:") { registrar = value }
            if created == nil, lower.contains("creation date") || lower.contains("created:") { created = value }
            if expires == nil, lower.contains("expir") { expires = value }
            if lower.contains("name server") || lower.contains("nserver") {
                if !value.isEmpty { nameservers.append(value.lowercased()) }
            }
        }

        return WHOISResult(
            raw: text,
            registrar: registrar,
            created: created,
            expires: expires,
            nameservers: Array(Set(nameservers)).sorted()
        )
    }
}
