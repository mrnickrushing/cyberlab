import Foundation

// MARK: - CVE Models

struct CVEResult: Identifiable, Equatable {
    let id: String          // CVE ID
    var summary: String
    var cvss: Double?
    var published: String
    var nvdURL: URL? { URL(string: "https://nvd.nist.gov/vuln/detail/\(id)") }
}

// MARK: - NVD response decoding

private struct NVDResponse: Decodable {
    let vulnerabilities: [NVDVuln]?
}
private struct NVDVuln: Decodable {
    let cve: NVDCve
}
private struct NVDCve: Decodable {
    let id: String
    let published: String?
    let descriptions: [NVDDescription]?
    let metrics: NVDMetrics?
}
private struct NVDDescription: Decodable {
    let lang: String
    let value: String
}
private struct NVDMetrics: Decodable {
    let cvssMetricV31: [NVDMetricEntry]?
    let cvssMetricV30: [NVDMetricEntry]?
    let cvssMetricV2: [NVDMetricEntry]?
}
private struct NVDMetricEntry: Decodable {
    let cvssData: NVDCvssData
}
private struct NVDCvssData: Decodable {
    let baseScore: Double?
}

// MARK: - CVE Search
//
// Queries the NIST National Vulnerability Database 2.0 REST API by keyword.

@MainActor
final class CVESearch: ObservableObject {
    @Published var results: [CVEResult] = []
    @Published var isSearching = false
    @Published var errorMessage: String?

    private var searchTask: Task<Void, Never>?

    /// Debounced keyword search (0.5s).
    func search(keyword raw: String) {
        let keyword = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        searchTask?.cancel()

        guard !keyword.isEmpty else {
            results = []
            errorMessage = nil
            isSearching = false
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled { return }

            self.isSearching = true
            self.errorMessage = nil
            do {
                let found = try await Self.fetch(keyword: keyword)
                if Task.isCancelled { return }
                self.results = found
                if found.isEmpty {
                    self.errorMessage = "No CVEs matched \"\(keyword)\"."
                }
            } catch {
                if Task.isCancelled { return }
                self.errorMessage = "Search failed: \(error.localizedDescription)"
            }
            self.isSearching = false
        }
    }

    static func fetch(keyword: String) async throws -> [CVEResult] {
        let encoded = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword
        guard let url = URL(string: "https://services.nvd.nist.gov/rest/json/cves/2.0?keywordSearch=\(encoded)&resultsPerPage=20") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(NVDResponse.self, from: data)

        return (decoded.vulnerabilities ?? []).map { vuln in
            let cve = vuln.cve
            let desc = cve.descriptions?.first(where: { $0.lang == "en" })?.value
                ?? cve.descriptions?.first?.value
                ?? "No description available."
            let score = cve.metrics?.cvssMetricV31?.first?.cvssData.baseScore
                ?? cve.metrics?.cvssMetricV30?.first?.cvssData.baseScore
                ?? cve.metrics?.cvssMetricV2?.first?.cvssData.baseScore
            let published = cve.published.map { String($0.prefix(10)) } ?? "—"
            return CVEResult(id: cve.id, summary: desc, cvss: score, published: published)
        }
    }
}
