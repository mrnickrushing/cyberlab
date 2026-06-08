import Foundation
import Combine

class ScanHistoryCache: ObservableObject {
    static let shared = ScanHistoryCache()
    private let key = "scan_history_cache"
    private let maxEntries = 50

    @Published var cachedScans: [ScanJob] = []

    private init() {
        load()
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let scans = try? JSONDecoder().decode([ScanJob].self, from: data) else { return }
        cachedScans = scans
    }

    func save(_ scans: [ScanJob]) {
        cachedScans = Array(scans.prefix(maxEntries))
        if let data = try? JSONEncoder().encode(cachedScans) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func add(_ scan: ScanJob) {
        var updated = cachedScans.filter { $0.id != scan.id }
        updated.insert(scan, at: 0)
        save(updated)
    }

    func clear() {
        cachedScans = []
        UserDefaults.standard.removeObject(forKey: key)
    }
}
