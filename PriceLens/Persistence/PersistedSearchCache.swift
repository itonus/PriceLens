import Foundation
import SwiftData

/// Persisted normalized-result cache backed by SwiftData (6h TTL).
/// Stores JSON-encoded offer snapshots only — never raw HTML.
@MainActor
final class PersistedSearchCache {
    private let context: ModelContext
    private let ttl: TimeInterval

    init(context: ModelContext, ttl: TimeInterval = AppConfig.default.persistedCacheTTL) {
        self.context = context
        self.ttl = ttl
    }

    func cachedResult(provider: SearchProviderID, key: String) -> ProviderSearchResult? {
        let predicate = #Predicate<SearchCacheRecord> { $0.key == key }
        var descriptor = FetchDescriptor<SearchCacheRecord>(predicate: predicate)
        descriptor.fetchLimit = 1
        guard let record = try? context.fetch(descriptor).first else { return nil }
        if Date().timeIntervalSince(record.createdAt) > ttl {
            context.delete(record)
            try? context.save()
            return nil
        }
        guard let cached = try? JSONDecoder().decode([CachedOffer].self, from: record.payload),
              let url = URL(string: record.searchURLString) else { return nil }

        let candidates: [OfferCandidate] = cached.compactMap { offer in
            guard let productURL = URL(string: offer.productURL),
                  let amount = Decimal(string: offer.itemPriceAmount) else { return nil }
            let delivery = offer.deliveryPriceAmount.flatMap { Decimal(string: $0) }
            return OfferCandidate(
                provider: provider,
                title: offer.title,
                url: productURL,
                rawPriceText: offer.itemPriceAmount,
                parsedItemPrice: Money(amount: amount, currencyCode: offer.itemPriceCurrency),
                rawDeliveryText: offer.deliveryPriceAmount,
                parsedDeliveryPrice: delivery.map { Money(amount: $0, currencyCode: offer.itemPriceCurrency) },
                seller: offer.seller,
                imageURL: nil,
                evidence: OfferEvidence(extractionStrategy: "persisted-cache")
            )
        }
        let state = ProviderSearchState(rawValue: record.stateRawValue) ?? .success
        return ProviderSearchResult(provider: provider, state: state, searchURL: url,
                                    offers: candidates, duration: .zero,
                                    debugSummary: "persisted cache hit")
    }

    func store(_ result: ProviderSearchResult, key: String) {
        guard result.state == .success || result.state == .partial, !result.offers.isEmpty else { return }
        let snapshot = result.offers.map { candidate in
            CachedOffer(
                title: candidate.title,
                productURL: candidate.url.absoluteString,
                itemPriceAmount: candidate.parsedItemPrice.map { "\($0.amount)" } ?? "",
                itemPriceCurrency: candidate.parsedItemPrice?.currencyCode ?? "PLN",
                deliveryPriceAmount: candidate.parsedDeliveryPrice.map { "\($0.amount)" },
                seller: candidate.seller,
                matchConfidenceRaw: "low"
            )
        }
        guard let payload = try? JSONEncoder().encode(snapshot) else { return }

        let predicate = #Predicate<SearchCacheRecord> { $0.key == key }
        var descriptor = FetchDescriptor<SearchCacheRecord>(predicate: predicate)
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            context.delete(existing)
        }
        context.insert(SearchCacheRecord(key: key, payload: payload,
                                         searchURLString: result.searchURL.absoluteString,
                                         stateRawValue: result.state.rawValue))
        try? context.save()
    }
}
