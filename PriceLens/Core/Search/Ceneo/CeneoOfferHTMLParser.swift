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

    /// Ceneo renders results with at least two different layouts — `cat-prod-row` for
    /// name searches and `js_product-row` for barcode/shop searches — which also disagree on
    /// attribute names (`data-productName` vs `data-GAProductName`) and casing (`data-brand` vs
    /// `data-Brand`). Selecting on the `data-productminprice` attribute instead of a class, and
    /// accepting several spellings per field, keeps one code path working across both.
    private func productRowStrategy(html: String) throws -> [OfferCandidate] {
        let document = try SwiftSoup.parse(html)
        let rows = try document.select("[data-productminprice]")

        return try rows.compactMap { row -> OfferCandidate? in
            let priceText = attribute(row, "data-productminprice", "data-price") ?? ""
            let productID = attribute(row, "data-pid", "data-productid") ?? ""

            // `data-GAProductName` is prefixed with the product id ("135917470/Regina …").
            var name = attribute(row, "data-productname", "data-product-name") ?? ""
            if name.isEmpty, let ga = attribute(row, "data-gaproductname") {
                name = ga.contains("/") ? String(ga.drop(while: { $0 != "/" }).dropFirst()) : ga
            }
            // Last resort: the thumbnail's alt text carries the product name.
            if name.isEmpty, let alt = try? row.select("img[alt]").first()?.attr("alt") {
                name = alt.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            guard !name.isEmpty, !productID.isEmpty,
                  let price = decimalPrice(priceText),
                  let url = URL(string: "https://www.ceneo.pl/\(productID)") else { return nil }

            let brand = attribute(row, "data-brand")

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

    /// First non-empty value among the given attribute names, matched case-insensitively —
    /// Ceneo mixes `data-brand` and `data-Brand` across layouts.
    private func attribute(_ element: Element, _ names: String...) -> String? {
        let attributes = element.getAttributes()
        for name in names {
            let wanted = name.lowercased()
            for attribute in attributes?.asList() ?? [] where attribute.getKey().lowercased() == wanted {
                let value = attribute.getValue().trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty { return value }
            }
        }
        return nil
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
