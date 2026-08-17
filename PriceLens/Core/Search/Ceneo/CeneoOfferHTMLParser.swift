import Foundation
import SwiftSoup

/// Ceneo listing page parser. Ordered strategies; unknown markup returns [].
/// All Ceneo selectors are contained here — nothing leaks into view models.
struct CeneoOfferHTMLParser: Sendable {

    struct ParserDiagnostics: Sendable {
        var strategyUsed: String?
        var offerCount: Int = 0
    }

    private let structuredData = StructuredDataExtractor()

    init() {}

    func parse(html: String, baseURL: URL) -> (offers: [OfferCandidate], diagnostics: ParserDiagnostics) {
        var diagnostics = ParserDiagnostics()

        // Product rows carry complete, explicit data attributes, so they are the primary
        // strategy here — richer and more stable than the single-item JSON-LD carousel.
        if let fromRows = try? productRowStrategy(html: html), !fromRows.isEmpty {
            diagnostics.strategyUsed = "product-row"
            diagnostics.offerCount = fromRows.count
            return (fromRows, diagnostics)
        }
        if let fromLD = try? structuredDataStrategy(html: html, baseURL: baseURL), !fromLD.isEmpty {
            diagnostics.strategyUsed = "json-ld"
            diagnostics.offerCount = fromLD.count
            return (fromLD, diagnostics)
        }
        return ([], diagnostics)
    }

    // MARK: - Strategy 1: product rows

    /// Each result is a `.cat-prod-row` carrying `data-productminprice`, `data-productName`,
    /// `data-brand` and `data-pid`, plus a thumbnail `<img>`.
    private func productRowStrategy(html: String) throws -> [OfferCandidate] {
        let document = try SwiftSoup.parse(html)
        let rows = try document.select("div.cat-prod-row[data-productminprice]")

        return try rows.compactMap { row -> OfferCandidate? in
            let priceText = try row.attr("data-productminprice")
            let name = try row.attr("data-productName").trimmingCharacters(in: .whitespacesAndNewlines)
            let productID = try row.attr("data-pid").trimmingCharacters(in: .whitespacesAndNewlines)

            guard !name.isEmpty, !productID.isEmpty,
                  let price = decimalPrice(priceText),
                  let url = URL(string: "https://www.ceneo.pl/\(productID)") else { return nil }

            let brand = try? row.attr("data-brand").trimmingCharacters(in: .whitespacesAndNewlines)

            // Thumbnails are protocol-relative ("//image.ceneostatic.pl/...").
            var imageURL: URL? = nil
            if let src = try? row.select("img[src]").first()?.attr("src"), !src.isEmpty {
                let absolute = src.hasPrefix("//") ? "https:\(src)" : src
                imageURL = URL(string: absolute)
            }

            return OfferCandidate(
                provider: .ceneo,
                title: name,
                url: url,
                rawPriceText: priceText,
                parsedItemPrice: Money(amount: price, currencyCode: "PLN"),
                // Ceneo lists the lowest *item* price across shops; delivery is not stated here,
                // so it stays unknown rather than being assumed free.
                rawDeliveryText: nil,
                parsedDeliveryPrice: nil,
                seller: nil,
                imageURL: imageURL,
                evidence: OfferEvidence(gtin: nil, mpn: nil,
                                        brand: (brand?.isEmpty == false) ? brand : nil,
                                        extractionStrategy: "product-row")
            )
        }
    }

    // MARK: - Strategy 2: JSON-LD

    private func structuredDataStrategy(html: String, baseURL: URL) throws -> [OfferCandidate] {
        structuredData.extract(fromHTML: html, baseURL: baseURL).compactMap { product in
            guard let name = product.name, let price = product.price else { return nil }
            return OfferCandidate(
                provider: .ceneo,
                title: name,
                url: product.url ?? baseURL,
                rawPriceText: "\(price.amount)",
                parsedItemPrice: price,
                rawDeliveryText: nil,
                parsedDeliveryPrice: nil,
                seller: product.seller,
                imageURL: product.imageURL,
                evidence: OfferEvidence(gtin: product.gtin, mpn: product.mpn, brand: product.brand,
                                        extractionStrategy: "json-ld")
            )
        }
    }

    /// Ceneo writes prices as plain dot-decimal attributes ("664.99"), independent of locale.
    private func decimalPrice(_ text: String) -> Decimal? {
        let cleaned = text.trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty,
              let value = Decimal(string: cleaned, locale: Locale(identifier: "en_US")),
              value > 0 else { return nil }
        return value
    }
}
