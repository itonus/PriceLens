import Foundation
import SwiftSoup

/// Allegro listing page parser. Ordered strategies; unknown markup returns [].
/// All selectors are contained here.
struct AllegroOfferHTMLParser: Sendable {

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
        if let fromJSON = try? embeddedStateStrategy(html: html, baseURL: baseURL), !fromJSON.isEmpty {
            diagnostics.strategyUsed = "embedded-state"
            diagnostics.offerCount = fromJSON.count
            return (fromJSON, diagnostics)
        }
        if let fromDOM = try? articleDOMStrategy(html: html, baseURL: baseURL), !fromDOM.isEmpty {
            diagnostics.strategyUsed = "article-dom"
            diagnostics.offerCount = fromDOM.count
            return (fromDOM, diagnostics)
        }
        return ([], diagnostics)
    }

    // MARK: - Strategy 1: JSON-LD

    private func structuredDataStrategy(html: String, baseURL: URL) throws -> [OfferCandidate] {
        structuredData.extract(fromHTML: html, baseURL: baseURL).compactMap { product in
            guard let name = product.name,
                  let url = product.url ?? product.price.map({ _ in baseURL }) else { return nil }
            return OfferCandidate(
                provider: .allegro,
                title: name,
                url: url,
                rawPriceText: product.price.map { "\($0.amount)" } ?? "",
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

    // MARK: - Strategy 2: embedded JSON state

    /// Allegro listing pages embed serialized offer objects with /oferta/ URLs and
    /// "sellingMode":{"price":{"amount":"1549.00","currency":"PLN"}}.
    private func embeddedStateStrategy(html: String, baseURL: URL) throws -> [OfferCandidate] {
        guard let regex = try? NSRegularExpression(
            pattern: #""(url|href)"\s*:\s*"(https?://allegro\.pl/oferta/[^"\\]+|/oferta/[^"\\]+)""#
        ) else { return [] }

        let range = NSRange(html.startIndex..., in: html)
        var candidates: [OfferCandidate] = []
        var seenURLs = Set<String>()

        for match in regex.matches(in: html, range: range) {
            guard let hrefRange = Range(match.range(at: 2), in: html),
                  let url = URLNormalizer.resolve(String(html[hrefRange]), base: baseURL) else { continue }
            let canonical = URLNormalizer.normalize(url).absoluteString
            guard seenURLs.insert(canonical).inserted else { continue }

            // Look in a window around the URL for title + price.
            let windowStart = max(html.startIndex, html.index(hrefRange.lowerBound, offsetBy: -800, limitedBy: html.startIndex) ?? html.startIndex)
            let windowEnd = html.index(hrefRange.upperBound, offsetBy: 2500, limitedBy: html.endIndex) ?? html.endIndex
            let window = String(html[windowStart..<windowEnd])

            guard let amount = firstJSONString("amount", in: window) ?? firstJSONNumber("amount", in: window),
                  let price = Decimal(string: amount.replacingOccurrences(of: ",", with: ".")) else { continue }
            let currency = firstJSONString("currency", in: window) ?? "PLN"

            let title = firstJSONString("name", in: window)
                ?? firstJSONString("title", in: window)
                ?? canonical
            let seller = firstJSONString("login", in: window)
            let deliveryFree = window.contains("\"freeDelivery\":true")
                || window.range(of: #""delivery"\s*:\s*\{[^}]*"price"\s*:\s*"0"#, options: .regularExpression) != nil

            candidates.append(OfferCandidate(
                provider: .allegro,
                title: decodeJSONEscapes(title),
                url: url,
                rawPriceText: amount,
                parsedItemPrice: Money(amount: price, currencyCode: currency),
                rawDeliveryText: nil,
                parsedDeliveryPrice: deliveryFree ? Money(amount: 0, currencyCode: currency) : nil,
                seller: seller.map(decodeJSONEscapes),
                imageURL: nil,
                evidence: OfferEvidence(extractionStrategy: "embedded-state",
                                      deliveryIsExplicitlyFree: deliveryFree)
            ))
        }
        return candidates
    }

    // MARK: - Strategy 3: article DOM

    private func articleDOMStrategy(html: String, baseURL: URL) throws -> [OfferCandidate] {
        let document = try SwiftSoup.parse(html, baseURL.absoluteString)
        var candidates: [OfferCandidate] = []
        var seenURLs = Set<String>()

        let articles = try document.select("article")
        for article in articles {
            guard let anchor = try article.select("a[href*='/oferta/']").first() else { continue }
            let href = try anchor.attr("href")
            guard let url = URLNormalizer.resolve(href, base: baseURL) else { continue }
            let canonical = URLNormalizer.normalize(url).absoluteString
            guard seenURLs.insert(canonical).inserted else { continue }

            let title = ((try? anchor.attr("aria-label")).flatMap { $0.isEmpty ? nil : $0 })
                ?? (try? anchor.text())
                ?? ""
            guard title.count > 3 else { continue }

            let articleText = (try? article.text()) ?? ""
            guard let price = PriceParser.parseFirst(in: articleText) else { continue }

            let lower = articleText.lowercased()
            let deliveryFree = lower.contains("darmowa dostawa") || lower.contains("dostawa za 0")
                || lower.contains("z allegro smart")

            candidates.append(OfferCandidate(
                provider: .allegro,
                title: TextNormalizer.cleanupForDisplay(title),
                url: url,
                rawPriceText: articleText,
                parsedItemPrice: price,
                rawDeliveryText: nil,
                parsedDeliveryPrice: deliveryFree ? Money(amount: 0, currencyCode: "PLN") : nil,
                seller: nil,
                imageURL: nil,
                evidence: OfferEvidence(extractionStrategy: "article-dom",
                                      deliveryIsExplicitlyFree: deliveryFree)
            ))
        }
        return candidates
    }

    // MARK: - JSON helpers

    private func firstJSONString(_ key: String, in text: String) -> String? {
        let pattern = "\"\(key)\"\\s*:\\s*\"([^\"\\\\]+)\""
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let valueRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[valueRange])
    }

    private func firstJSONNumber(_ key: String, in text: String) -> String? {
        let pattern = "\"\(key)\"\\s*:\\s*(\\d+(?:[.,]\\d+)?)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let valueRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[valueRange])
    }

    private func decodeJSONEscapes(_ string: String) -> String {
        string.replacingOccurrences(of: "\\u002F", with: "/")
            .replacingOccurrences(of: "\\/", with: "/")
            .replacingOccurrences(of: "\\u0026", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}
