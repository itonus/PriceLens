import Foundation

/// Orchestrates provider searches for one scan session: sequential query fallback
/// per provider, concurrent providers, progressive updates, cancellation on supersede.
@MainActor
final class SearchCoordinator {

    enum Event: Sendable {
        case sessionStarted(UUID)
        case providerSearching(sessionID: UUID, SearchProviderID)
        case providerResult(sessionID: UUID, result: ProviderSearchResult, offers: [Offer])
        case sessionFinished(UUID)
    }

    private let config: AppConfig
    private let cache: SearchCache
    private let matcher: OfferMatcher
    private var providers: [SearchProviderID: any SearchProvider]
    /// Optional SwiftData-backed cache (6h). Checked after memory, before network.
    var persistedCache: PersistedSearchCache?

    private var currentTask: Task<Void, Never>?
    private var currentSessionID: UUID?

    init(config: AppConfig = .default,
         providers: [any SearchProvider],
         cache: SearchCache = SearchCache(),
         matcher: OfferMatcher = OfferMatcher(),
         persistedCache: PersistedSearchCache? = nil) {
        self.config = config
        self.cache = cache
        self.matcher = matcher
        self.providers = Dictionary(uniqueKeysWithValues: providers.map { ($0.id, $0) })
        self.persistedCache = persistedCache
    }

    func replaceProviders(_ providers: [any SearchProvider]) {
        self.providers = Dictionary(uniqueKeysWithValues: providers.map { ($0.id, $0) })
    }

    /// Providers that are actually wired up. Callers must intersect their enabled set with this:
    /// asking for an unregistered provider would leave its status spinning forever, because no
    /// result is ever emitted for it.
    var registeredProviderIDs: Set<SearchProviderID> { Set(providers.keys) }

    func cancelCurrent() {
        currentTask?.cancel()
        currentTask = nil
    }

    /// Starts a search for the session; returns a stream of progressive events.
    /// Cancels any in-flight search and ignores its late results.
    func startSearch(session: SearchSession,
                     enabledProviders: [SearchProviderID]) -> AsyncStream<Event> {
        cancelCurrent()

        let sessionID = session.id
        currentSessionID = sessionID
        let queries = session.identity.queryCandidates
        let activeQueries = queries.isEmpty ? [session.activeQuery] : queries

        let (stream, continuation) = AsyncStream<Event>.makeStream()

        let task = Task { [weak self] in
            guard let self else { continuation.finish(); return }
            continuation.yield(.sessionStarted(sessionID))

            await withTaskGroup(of: Void.self) { group in
                for providerID in enabledProviders {
                    guard let provider = self.providers[providerID] else { continue }
                    group.addTask { [weak self] in
                        await self?.runProvider(provider: provider,
                                                sessionID: sessionID,
                                                identity: session.identity,
                                                queries: activeQueries,
                                                continuation: continuation)
                    }
                }
            }

            continuation.yield(.sessionFinished(sessionID))
            continuation.finish()
        }
        currentTask = task

        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in
                if self?.currentSessionID == sessionID { self?.currentTask?.cancel() }
            }
        }

        return stream
    }

    // MARK: - Provider pipeline

    private func runProvider(provider: any SearchProvider,
                             sessionID: UUID,
                             identity: ProductIdentity,
                             queries: [String],
                             continuation: AsyncStream<Event>.Continuation) async {
        continuation.yield(.providerSearching(sessionID: sessionID, provider.id))

        var lastResult: ProviderSearchResult?
        for query in queries where !query.isEmpty {
            if Task.isCancelled { return }

            let cacheKey = SearchCache.key(provider: provider.id, query: query, region: config.countryCode)
            if let cached = await cache.cachedResult(for: cacheKey) {
                emit(result: cached, identity: identity, sessionID: sessionID, continuation: continuation)
                return
            }
            if let persisted = persistedCache?.cachedResult(provider: provider.id, key: cacheKey) {
                await cache.store(persisted, for: cacheKey)
                emit(result: persisted, identity: identity, sessionID: sessionID, continuation: continuation)
                return
            }

            let request = ProductSearchRequest(
                identity: identity,
                query: query,
                countryCode: config.countryCode,
                currencyCode: config.currencyCode,
                preferredLanguage: "pl"
            )
            let result = await provider.search(request)
            if Task.isCancelled { return }
            lastResult = result

            if !result.offers.isEmpty {
                await cache.store(result, for: cacheKey)
                persistedCache?.store(result, key: cacheKey)
                emit(result: result, identity: identity, sessionID: sessionID, continuation: continuation)
                return
            }

            // Offline/blocked: retrying with a different query won't help.
            if result.state == .offline || result.state == .blocked || result.state == .failed {
                emit(result: result, identity: identity, sessionID: sessionID, continuation: continuation)
                return
            }
            // fallbackOnly with zero offers: try next query candidate.
        }

        if let lastResult {
            emit(result: lastResult, identity: identity, sessionID: sessionID, continuation: continuation)
        }
    }

    private func emit(result: ProviderSearchResult,
                      identity: ProductIdentity,
                      sessionID: UUID,
                      continuation: AsyncStream<Event>.Continuation) {
        let offers = normalize(result.offers, identity: identity)
        continuation.yield(.providerResult(sessionID: sessionID, result: result, offers: offers))
    }

    // MARK: - Normalization

    /// Candidates -> Offers: drop unpriced, compute match confidence, dedupe by URL, totals.
    func normalize(_ candidates: [OfferCandidate], identity: ProductIdentity) -> [Offer] {
        var seenURLs = Set<String>()
        var offers: [Offer] = []

        for candidate in candidates {
            guard let itemPrice = candidate.parsedItemPrice else { continue }
            let canonicalURL = URLNormalizer.normalize(candidate.url)
            guard seenURLs.insert(canonicalURL.absoluteString).inserted else { continue }

            let confidence = matcher.confidence(identity: identity,
                                                offerTitle: candidate.title,
                                                evidence: candidate.evidence)
            let delivery = candidate.parsedDeliveryPrice
            var total: Money? = nil
            if let delivery, delivery.isCompatible(with: itemPrice) {
                total = Money(amount: itemPrice.amount + delivery.amount, currencyCode: itemPrice.currencyCode)
            }
            let extractionConfidence: Double = switch candidate.evidence.extractionStrategy {
            case "json-ld": 0.9
            case "embedded-state": 0.75
            default: 0.6
            }

            offers.append(Offer(
                id: "\(candidate.provider.rawValue)-\(canonicalURL.absoluteString.hashValue)",
                provider: candidate.provider,
                title: candidate.title,
                productURL: candidate.url,
                imageURL: candidate.imageURL,
                itemPrice: itemPrice,
                deliveryPrice: delivery,
                totalPrice: total,
                seller: candidate.seller,
                matchConfidence: confidence,
                extractionConfidence: extractionConfidence
            ))
        }
        return offers
    }
}
