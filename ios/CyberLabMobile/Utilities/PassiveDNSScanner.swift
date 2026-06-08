import Foundation

// MARK: - Passive DNS Models

struct DNSHostEntry: Identifiable, Equatable {
    let id = UUID()
    var hostname: String
    var ip: String
}

// MARK: - Passive DNS Scanner
//
// Uses HackerTarget's free APIs to retrieve current DNS records and historical
// host/IP associations for a domain. Responses are plain text, newline
// separated. The free tier may return an "API count exceeded" error string,
// which we surface verbatim.

@MainActor
final class PassiveDNSScanner: ObservableObject {
    @Published var hosts: [DNSHostEntry] = []
    @Published var currentDNS: String = ""
    @Published var isScanning = false
    @Published var errorMessage: String?

    func scan(domain raw: String) {
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
        hosts = []
        currentDNS = ""

        Task {
            async let dns = Self.fetchText(path: "dnslookup", query: domain)
            async let hostsText = Self.fetchText(path: "hostsearch", query: domain)
            do {
                let (dnsResult, hostsResult) = try await (dns, hostsText)
                // HackerTarget returns error text in the body rather than HTTP errors
                let dnsLower = dnsResult.lowercased()
                if dnsLower.hasPrefix("error") || dnsLower.contains("api count exceeded") || dnsLower.contains("you have exceeded") {
                    self.errorMessage = dnsResult.trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    self.currentDNS = dnsResult
                    self.hosts = Self.parseHosts(hostsResult)
                    if self.hosts.isEmpty && self.currentDNS.isEmpty {
                        self.errorMessage = "No passive DNS data returned for \(domain)."
                    }
                }
            } catch {
                self.errorMessage = "Lookup failed: \(error.localizedDescription)"
            }
            self.isScanning = false
        }
    }

    static func fetchText(path: String, query: String) async throws -> String {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://api.hackertarget.com/\(path)/?q=\(encoded)") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 25
        let (data, _) = try await URLSession.shared.data(for: request)
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func parseHosts(_ text: String) -> [DNSHostEntry] {
        text.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: ",", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { return nil }
            return DNSHostEntry(hostname: parts[0], ip: parts[1])
        }
    }
}
