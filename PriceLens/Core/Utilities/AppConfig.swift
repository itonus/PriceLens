import Foundation

/// Central configuration. Do not scatter constants through the codebase.
struct AppConfig: Sendable {
    var countryCode = "PL"
    var currencyCode = "PLN"

    /// Search providers
    var providerTimeout: TimeInterval = 8
    var memoryCacheTTL: TimeInterval = 30 * 60
    var persistedCacheTTL: TimeInterval = 6 * 60 * 60
    var userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
    /// WKWebView rendered fallback. Slower and more challenge-prone, but Google's shopping
    /// surface is fully JS-gated over URLSession (verified live: 200 OK, ~90KB, zero prices,
    /// zero JSON-LD), so without rendering the app can only ever show the fallback link.
    var useRenderedFallback = true

    /// Scanner
    var barcodeLockInterval: TimeInterval = 0.45
    var candidateExpireInterval: TimeInterval = 1.2
    var priceAssociationRadius: CGFloat = 0.28 // fraction of view height around product
    var ocrLanguages = ["pl-PL", "en-US", "ru-RU"]

    /// Decision thresholds (see PRODUCT_SPEC §7)
    var goodThreshold: Decimal = 1.05
    var fairThreshold: Decimal = 1.10

    /// History
    var historyLimit = 200

    static let `default` = AppConfig()
}
