import Foundation
import SwiftSoup

/// Google shopping page parser. Ordered strategies; unknown markup returns [].
/// All selectors are contained here — never spread through the app.
struct GoogleOfferHTMLParser: Sendable {

    struct ParserDiagnostics: Sendable {
        var strategyUsed: String?
        var offerCount: Int = 0
    }

    private let structuredData = StructuredDataExtractor()

    init() {}

    func parse(html: String, baseURL: URL) -> (offers: [OfferCandidate], diagnostics: ParserDiagnostics) {
        var diagnostics = ParserDiagnostics()

        if let fromLD = try? structuredDataStrategy(html: html, baseURL: baseURL), !fromLD.isEmpty {
            diagnostics.strategyUsed = "json-ld"
            diagnostics.offerCount = fromLD.count
            return (fromLD, diagnostics)
        }
        if let fromLinks = try? shoppingLinksStrategy(html: html, baseURL: baseURL), !fromLinks.isEmpty {
            diagnostics.strategyUsed = "shopping-links"
            diagnostics.offerCount = fromLinks.count
            return (fromLinks, diagnostics)
        }
        diagnostics.offerCount = 0
        return ([], diagnostics)
    }

    // MARK: - Strategy 1: JSON-LD structured data

    private func structuredDataStrategy(html: String, baseURL: URL) throws -> [OfferCandidate] {
        structuredData.extract(fromHTML: html, baseURL: baseURL).compactMap { product in
            guard let name = product.name,
                  let priceText = product.price.map({ "\($0.amount)" }),
                  let url = product.url else { return nil }
            return OfferCandidate(
                provider: .google,
                title: name,
                url: url,
                rawPriceText: priceText,
                parsedItemPrice: product.price,
                rawDeliveryText: nil,
                parsedDeliveryPrice: nil,
                seller: product.seller,
                imageURL: product.imageURL,
                evidence: OfferEvidence(gtin: product.gtin, mpn: product.mpn, brand: product.brand,
                                      extractionStrategy: "json-ld")
            )
        }
    }

    // MARK: - Strategy 2: semantic shopping links

    /// Product cards link to /shopping/product/... or carry a price next to a merchant link.
    private func shoppingLinksStrategy(html: String, baseURL: URL) throws -> [OfferCandidate] {
        let document = try SwiftSoup.parse(html, baseURL.absoluteString)
        var candidates: [OfferCandidate] = []
        var seenURLs = Set<String>()

        let anchors = try document.select("a[href]")
        for anchor in anchors {
            let href = try anchor.attr("href")
            guard href.contains("/shopping/product/") || href.hasPrefix("/url?q=") else { continue }

            guard let url = URLNormalizer.resolve(href, base: baseURL).map(URLNormalizer.unwrapGoogleRedirect) else { continue }
            let canonical = URLNormalizer.normalize(url).absoluteString
            guard seenURLs.insert(canonical).inserted else { continue }

            // Title: anchor text, else aria-label, else first heading inside.
            var title = (try? anchor.text()) ?? ""
            if title.count < 4, let aria = try? anchor.attr("aria-label"), !aria.isEmpty { title = aria }
            if title.count < 4 { continue }

            // Price: nearest enclosing block's text.
            let container = nearestBlock(anchor)
            var containerText = ""
            if let container {
                containerText = (try? container.text()) ?? ""
            }
            guard !containerText.isEmpty, let price = PriceParser.parseFirst(in: containerText) else { continue }

            let deliveryPrice = deliveryFrom(containerText: containerText)

            candidates.append(OfferCandidate(
                provider: .google,
                title: TextNormalizer.cleanupForDisplay(title),
                url: url,
                rawPriceText: containerText,
                parsedItemPrice: price,
                rawDeliveryText: nil,
                parsedDeliveryPrice: deliveryPrice,
                seller: sellerFrom(containerText: containerText),
                imageURL: nil,
                evidence: OfferEvidence(extractionStrategy: "shopping-links",
                                        deliveryIsExplicitlyFree: deliveryPrice?.amount == 0)
            ))
        }
        return candidates
    }

    // MARK: - Helpers

    private func nearestBlock(_ element: Element) -> Element? {
        var current: Element? = element
        var hops = 0
        while let node = current, hops < 5 {
            if let text = try? node.text(), PriceParser.parseFirst(in: text) != nil {
                return node
            }
            current = node.parent()
            hops += 1
        }
        return nil
    }

    private func deliveryFrom(containerText: String) -> Money? {
        let lower = containerText.lowercased()
        if lower.contains("darmowa dostawa") || lower.contains("free delivery") || lower.contains("free shipping") {
            return Money(amount: 0, currencyCode: "PLN")
        }
        guard lower.contains("dostawa") || lower.contains("delivery") || lower.contains("shipping") else { return nil }
        // "Dostawa 9,99 zł"
        if let range = lower.range(of: #"dostawa[^0-9]{0,12}"#, options: .regularExpression) {
            let tail = String(containerText[range.upperBound...])
            return PriceParser.parseFirst(in: tail)
        }
        return nil
    }

    private func sellerFrom(containerText: String) -> String? {
        // Google shopping cards usually end with the merchant name after the price.
        let parts = containerText.components(separatedBy: "·")
        guard parts.count > 1, let last = parts.last?.trimmingCharacters(in: .whitespaces),
              last.count > 1, last.count < 60 else { return nil }
        return last
    }
}
