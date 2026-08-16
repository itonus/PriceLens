import Foundation

struct ProductSearchRequest: Sendable {
    let identity: ProductIdentity
    let query: String
    let countryCode: String
    let currencyCode: String
    let preferredLanguage: String
}

struct ProviderSearchResult: Sendable {
    let provider: SearchProviderID
    let state: ProviderSearchState
    /// Canonical user-facing search URL — always present, used for fallback actions.
    let searchURL: URL
    let offers: [OfferCandidate]
    let duration: Duration
    /// Safe diagnostics (no raw HTML, no cookies). Shown only in DEBUG.
    let debugSummary: String?
}

/// A search provider. Web extraction is best-effort; implementations never throw
/// provider-specific errors into the UI — they return a typed state instead.
protocol SearchProvider: Sendable {
    var id: SearchProviderID { get }
    func search(_ request: ProductSearchRequest) async -> ProviderSearchResult
}
