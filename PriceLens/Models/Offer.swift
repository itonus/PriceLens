import Foundation

enum SearchProviderID: String, Codable, Sendable, CaseIterable, Identifiable {
    case ceneo
    case google
    case allegro

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ceneo: return "Ceneo"
        case .google: return "Google"
        case .allegro: return "Allegro"
        }
    }
}

enum ProviderSearchState: String, Sendable {
    case success
    case partial
    case fallbackOnly
    case blocked
    case offline
    case failed
}

enum MatchConfidence: String, Sendable, Hashable, Comparable, Codable {
    case exact
    case high
    case medium
    case low

    private var rank: Int {
        switch self {
        case .exact: return 3
        case .high: return 2
        case .medium: return 1
        case .low: return 0
        }
    }

    static func < (lhs: MatchConfidence, rhs: MatchConfidence) -> Bool { lhs.rank < rhs.rank }

    /// Only exact/high may drive the purchase recommendation.
    var isRecommendationEligible: Bool { self >= .high }
}

/// Evidence kept from the provider page for honest matching and DEBUG diagnostics.
struct OfferEvidence: Sendable, Hashable {
    var gtin: String?
    var mpn: String?
    var brand: String?
    var extractionStrategy: String
    var deliveryIsExplicitlyFree: Bool = false
}

/// Raw parsed candidate straight from a provider parser, before normalization.
struct OfferCandidate: Sendable, Hashable {
    let provider: SearchProviderID
    let title: String
    let url: URL
    let rawPriceText: String
    let parsedItemPrice: Money?
    let rawDeliveryText: String?
    let parsedDeliveryPrice: Money?
    let seller: String?
    let imageURL: URL?
    let evidence: OfferEvidence
}

/// Normalized offer used by the UI and decision engine.
struct Offer: Identifiable, Sendable, Hashable {
    let id: String
    let provider: SearchProviderID
    let title: String
    let productURL: URL
    let imageURL: URL?
    let itemPrice: Money
    let deliveryPrice: Money?
    let totalPrice: Money?
    let seller: String?
    let matchConfidence: MatchConfidence
    let extractionConfidence: Double

    /// Effective comparison price: delivered total when known, otherwise item price.
    var comparisonPrice: Money { totalPrice ?? itemPrice }
}
