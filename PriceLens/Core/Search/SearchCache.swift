import Foundation

/// Shared in-memory + persisted cache of normalized provider results.
/// Actor-isolated. Never stores raw HTML.
actor SearchCache {

    struct Entry: Sendable {
        let result: ProviderSearchResult
        let createdAt: Date
    }

    private var memory: [String: Entry] = [:]
    private let memoryTTL: TimeInterval

    init(memoryTTL: TimeInterval = AppConfig.default.memoryCacheTTL) {
        self.memoryTTL = memoryTTL
    }

    static func key(provider: SearchProviderID, query: String, region: String) -> String {
        let normalized = TextNormalizer.normalizeForMatching(query)
        return "\(provider.rawValue)|\(region)|\(normalized)"
    }

    func cachedResult(for key: String) -> ProviderSearchResult? {
        guard let entry = memory[key] else { return nil }
        if Date().timeIntervalSince(entry.createdAt) > memoryTTL {
            memory[key] = nil
            return nil
        }
        return entry.result
    }

    func store(_ result: ProviderSearchResult, for key: String) {
        // Only cache states worth reusing.
        guard result.state == .success || result.state == .partial else { return }
        memory[key] = Entry(result: result, createdAt: Date())
        if memory.count > 100 {
            let oldest = memory.sorted { $0.value.createdAt < $1.value.createdAt }.prefix(20)
            for (key, _) in oldest { memory[key] = nil }
        }
    }

    func clear() { memory.removeAll() }
}
