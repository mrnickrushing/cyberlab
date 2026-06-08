import Foundation

// MARK: - Reverse IP Models

struct ReverseIPDomain: Identifiable, Equatable {
    let id = UUID()
    var domain: String
}

// MARK: - Reverse IP Scanner
//
// Resolves all domains that share a given IP address via HackerTarget's free
// reverse-IP API. The response is a newline-separated list of hostnames.

@MainActor
final class ReverseIPScanner: ObservableObject {
    @Published var domains: [ReverseIPDomain] = []
    @Published var isScanning = false
    @Published var errorMessage: String?

    var count: Int { domains.count }

    func scan(ip raw: String) {
        let ip = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ip.isEmpty else {
            errorMessage = "Enter an IP address."
            return
        }

        isScanning = true
        errorMessage = nil
        domains = []

        Task {
            do {
                let text = try await PassiveDNSScanner.fetchText(path: "reverseiplookup", query: ip)
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.lowercased().contains("error") || trimmed.lowercased().contains("no records") {
                    self.errorMessage = trimmed
                } else {
                    self.domains = trimmed
                        .split(separator: "\n")
                        .map { ReverseIPDomain(domain: $0.trimmingCharacters(in: .whitespaces)) }
                        .filter { !$0.domain.isEmpty }
                    if self.domains.isEmpty {
                        self.errorMessage = "No domains found for \(ip)."
                    }
                }
            } catch {
                self.errorMessage = "Lookup failed: \(error.localizedDescription)"
            }
            self.isScanning = false
        }
    }
}
