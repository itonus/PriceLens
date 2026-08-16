import Foundation
import SwiftData

/// Persisted normalized search-result cache (6h TTL). Never stores raw HTML.
@Model
final class SearchCacheRecord {
    @Attribute(.unique) var key: String // provider + normalized query + region
    var createdAt: Date
    var payload: Data // JSON-encoded [CachedOffer]
    var searchURLString: String
    var stateRawValue: String

    init(key: String, createdAt: Date = Date(), payload: Data, searchURLString: String, stateRawValue: String) {
        self.key = key
        self.createdAt = createdAt
        self.payload = payload
        self.searchURLString = searchURLString
        self.stateRawValue = stateRawValue
    }
}

/// Codable snapshot of a normalized offer for the persisted cache.
struct CachedOffer: Codable, Sendable {
    var title: String
    var productURL: String
    var itemPriceAmount: String
    var itemPriceCurrency: String
    var deliveryPriceAmount: String?
    var seller: String?
    var matchConfidenceRaw: String
}
