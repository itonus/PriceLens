import Foundation

/// Drives the result bottom sheet: progressive provider updates, decision, editing.
@Observable
@MainActor
final class ResultsViewModel {

    struct ProviderStatus: Equatable {
        var isSearching = true
        var state: ProviderSearchState?
        var offerCount = 0
        var searchURL: URL?
        var debugSummary: String?
    }

    let sessionID: UUID
    private let container: AppContainer
    private let decisionEngine = DecisionEngine()

    var identity: ProductIdentity
    var storePrice: Money?
    /// Real product behind the barcode, once resolved. Drives the header title/image.
    var resolvedProduct: ResolvedProduct?
    var offers: [Offer] = []
    var providerStatus: [SearchProviderID: ProviderStatus] = [:]
    var sortOrder: OfferSortOrder = .bestMatch
    var isFinished = false
    var savedToHistory = false

    var decision: PurchaseDecision = .empty

    /// Enabled providers for this session.
    let enabledProviders: [SearchProviderID]

    private var searchTask: Task<Void, Never>?
    private var resolveTask: Task<Void, Never>?

    init(session: SearchSession, container: AppContainer) {
        self.container = container
        self.sessionID = session.id
        self.identity = session.identity
        self.storePrice = session.storePrice
        let registered = container.searchCoordinator.registeredProviderIDs
        self.enabledProviders = SearchProviderID.allCases.filter {
            registered.contains($0) && container.settings.isProviderEnabled($0)
        }
    }

    func stop() {
        searchTask?.cancel()
        searchTask = nil
        resolveTask?.cancel()
        resolveTask = nil
        container.searchCoordinator.cancelCurrent()
    }

    /// Resolves what the barcode actually is, then re-runs the search with the real product
    /// name. OCR text from packaging is unreliable (serials, lot codes, shipping labels), so a
    /// confirmed product name is a far better query — but only when lookup genuinely succeeds.
    private func resolveProductIfPossible() {
        resolveTask?.cancel()
        guard let resolver = container.productResolver,
              let barcode = identity.barcode, !barcode.isEmpty else { return }

        resolveTask = Task { [weak self] in
            guard let self, let resolved = await resolver.resolve(barcode: barcode) else { return }
            guard !Task.isCancelled, let title = resolved.displayTitle else { return }
            self.resolvedProduct = resolved

            // Adopt the confirmed identity and search again with it.
            guard title.caseInsensitiveCompare(self.identity.query) != .orderedSame else { return }
            self.identity.brand = resolved.brand ?? self.identity.brand
            self.identity.titleHint = title
            self.identity.query = title
            self.start()
        }
    }

    // MARK: - Search lifecycle

    func start() {
        searchTask?.cancel()
        let session = SearchSession(id: sessionID, identity: identity, storePrice: storePrice,
                                    activeQuery: identity.query)
        offers = []
        isFinished = false
        providerStatus = Dictionary(uniqueKeysWithValues: enabledProviders.map { ($0, ProviderStatus()) })
        recomputeDecision()

        let stream = container.searchCoordinator.startSearch(session: session,
                                                             enabledProviders: enabledProviders)
        searchTask = Task { [weak self] in
            for await event in stream {
                guard let self, !Task.isCancelled else { return }
                self.handle(event)
            }
        }
    }

    /// Entry point for a freshly presented sheet: search immediately with what the scanner saw,
    /// and resolve the barcode in parallel so results improve as soon as the real product is
    /// known. Kept separate from `start()` so the re-search triggered by a successful resolve
    /// cannot cancel the resolve task that is driving it.
    func begin() {
        start()
        resolveProductIfPossible()
    }

    func retry() {
        start()
    }

    private func handle(_ event: SearchCoordinator.Event) {
        switch event {
        case .sessionStarted(let id):
            guard id == sessionID else { return }
        case .providerSearching(let id, let provider):
            guard id == sessionID else { return }
            providerStatus[provider]?.isSearching = true
        case .providerResult(let id, let result, let newOffers):
            guard id == sessionID else { return }
            var status = providerStatus[result.provider] ?? ProviderStatus()
            status.isSearching = false
            status.state = result.state
            status.offerCount = newOffers.count
            status.searchURL = result.searchURL
            status.debugSummary = result.debugSummary
            providerStatus[result.provider] = status

            offers.append(contentsOf: newOffers)
            offers = OfferSorting.sort(offers, order: sortOrder)
            recomputeDecision()
        case .sessionFinished(let id):
            guard id == sessionID else { return }
            isFinished = true
            saveHistoryIfNeeded()
        }
    }

    // MARK: - Editing

    /// User edits the detected query: rerun search.
    func updateQuery(_ newQuery: String) {
        let cleaned = TextNormalizer.cleanupForDisplay(newQuery)
        guard !cleaned.isEmpty, cleaned != identity.query else { return }
        identity.query = cleaned
        if identity.barcode == nil { identity.titleHint = cleaned }
        start()
    }

    /// User edits the store price: decision updates immediately.
    func updateStorePrice(_ newPrice: Money?) {
        storePrice = newPrice
        recomputeDecision()
    }

    func changeSortOrder(_ order: OfferSortOrder) {
        sortOrder = order
        offers = OfferSorting.sort(offers, order: order)
    }

    // MARK: - Decision

    private func recomputeDecision() {
        decision = decisionEngine.decision(storePrice: storePrice, offers: offers)
    }

    /// Merges a better identity (from the high-res still path) into the active session.
    func applyEnhancement(_ enhanced: ProductIdentity, price: Money?) {
        var identityChanged = false
        if enhanced.query != identity.query || enhanced.model != identity.model {
            identity = enhanced
            identityChanged = true
        }
        if storePrice == nil, let price {
            storePrice = price
        }
        if identityChanged {
            start()
        } else {
            recomputeDecision()
        }
    }

    // MARK: - History

    private func saveHistoryIfNeeded() {
        guard !savedToHistory else { return }
        savedToHistory = true
        let summary = providerStatus
            .map { "\($0.key.rawValue):\($0.value.state?.rawValue ?? "searching")(\($0.value.offerCount))" }
            .sorted()
            .joined(separator: ",")
        container.historyRepository.save(
            query: identity.query,
            barcode: identity.barcode,
            storePrice: storePrice,
            bestPrice: decision.bestOffer?.comparisonPrice,
            recommendation: decision.recommendation,
            providerSummary: summary
        )
    }

    /// Called from History when re-running an old scan.
    static func session(for record: ScanHistoryRecord) -> SearchSession {
        let identity = ProductIdentity(barcode: record.barcode, brand: nil, model: nil,
                                       titleHint: record.query, rawRecognizedText: [],
                                       query: record.query)
        return SearchSession(identity: identity, storePrice: record.storePrice, activeQuery: record.query)
    }
}
