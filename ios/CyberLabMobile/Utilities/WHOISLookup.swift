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
// Submits a WHOIS scan job through the CyberLab backend (which runs the
// system `whois` binary). Falls back to HackerTarget only if the backend
// returns an error. This avoids the "valid key required" rate-limit that
// HackerTarget imposes on direct free-tier calls from the phone.

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
                let text = try await fetchViaBackend(domain: domain)
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

    // Poll backend scan endpoint. WHOIS is fast so we poll every 2 seconds,
    // timeout after 30 seconds.
    private func fetchViaBackend(domain: String) async throws -> String {
        let base = APIClient.shared.baseURL
        guard let token = KeychainManager.load(.accessToken) else {
            throw URLError(.userAuthenticationRequired)
        }

        // 1. Submit scan job
        guard let submitURL = URL(string: "\(base)/api/scans") else { throw URLError(.badURL) }
        var submitReq = URLRequest(url: submitURL)
        submitReq.httpMethod = "POST"
        submitReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        submitReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = ["tool": "whois", "target": domain, "options": [:]]
        submitReq.httpBody = try JSONSerialization.data(withJSONObject: body)
        submitReq.timeoutInterval = 30

        let (submitData, _) = try await URLSession.shared.data(for: submitReq)
        guard let json = try JSONSerialization.jsonObject(with: submitData) as? [String: Any],
              let scanId = json["id"] as? String else {
            throw URLError(.cannotParseResponse)
        }

        // 2. Poll for result
        guard let pollURL = URL(string: "\(base)/api/scans/\(scanId)") else { throw URLError(.badURL) }
        var pollReq = URLRequest(url: pollURL)
        pollReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        pollReq.timeoutInterval = 30

        for _ in 0..<15 {
            try await Task.sleep(nanoseconds: 2_000_000_000) // wait 2s
            let (pollData, _) = try await URLSession.shared.data(for: pollReq)
            guard let pollJson = try JSONSerialization.jsonObject(with: pollData) as? [String: Any] else { continue }
            let status = pollJson["status"] as? String ?? ""
            if status == "completed" || status == "failed" {
                // Extract output text
                if let output = pollJson["output"] as? String, !output.isEmpty {
                    return output
                }
                if let result = pollJson["result"] as? [String: Any],
                   let output = result["output"] as? String {
                    return output
                }
                throw URLError(.zeroByteResource)
            }
        }
        throw URLError(.timedOut)
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
