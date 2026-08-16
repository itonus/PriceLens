import Foundation

/// Extracts Product/Offer-shaped data from application/ld+json blocks.
/// Supports object, array, and @graph forms. Tolerant decoding; never throws to callers.
struct StructuredDataExtractor: Sendable {

    struct ExtractedProduct: Sendable, Hashable {
        var name: String?
        var gtin: String?
        var mpn: String?
        var brand: String?
        var price: Money?
        var priceCurrency: String?
        var url: URL?
        var seller: String?
        var imageURL: URL?
    }

    init() {}

    /// HTML string -> products found in JSON-LD blocks.
    func extract(fromHTML html: String, baseURL: URL) -> [ExtractedProduct] {
        let blocks = jsonLDBlocks(in: html)
        var products: [ExtractedProduct] = []
        for block in blocks {
            guard let data = block.data(using: .utf8) else { continue }
            guard let object = try? JSONSerialization.jsonObject(with: data) else { continue }
            products.append(contentsOf: walk(object, baseURL: baseURL))
        }
        return products
    }

    // MARK: - Internals

    private func jsonLDBlocks(in html: String) -> [String] {
        var blocks: [String] = []
        let pattern = #"<script[^>]*type=["']application/ld\+json["'][^>]*>(.*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return [] }
        let range = NSRange(html.startIndex..., in: html)
        for match in regex.matches(in: html, range: range) {
            if let blockRange = Range(match.range(at: 1), in: html) {
                let content = String(html[blockRange])
                    .replacingOccurrences(of: "<!--", with: "")
                    .replacingOccurrences(of: "-->", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !content.isEmpty { blocks.append(content) }
            }
        }
        return blocks
    }

    private func walk(_ object: Any, baseURL: URL) -> [ExtractedProduct] {
        if let dict = object as? [String: Any] {
            return walkDict(dict, baseURL: baseURL)
        }
        if let array = object as? [Any] {
            return array.flatMap { walk($0, baseURL: baseURL) }
        }
        return []
    }

    private func walkDict(_ dict: [String: Any], baseURL: URL) -> [ExtractedProduct] {
        var result: [ExtractedProduct] = []

        if let type = dict["@type"] as? String, type == "Product" || type == "Offer" {
            if let product = parseProduct(dict, baseURL: baseURL) {
                result.append(product)
            }
        }
        if let types = dict["@type"] as? [String], types.contains("Product") {
            if let product = parseProduct(dict, baseURL: baseURL) {
                result.append(product)
            }
        }
        if let graph = dict["@graph"] {
            result.append(contentsOf: walk(graph, baseURL: baseURL))
        }
        if let itemList = dict["itemListElement"] {
            result.append(contentsOf: walk(itemList, baseURL: baseURL))
        }
        if let item = dict["item"] {
            result.append(contentsOf: walk(item, baseURL: baseURL))
        }
        if let offers = dict["offers"], !(dict["@type"] as? String == "Offer") {
            result.append(contentsOf: walk(offers, baseURL: baseURL))
        }
        return result
    }

    private func parseProduct(_ dict: [String: Any], baseURL: URL) -> ExtractedProduct? {
        var product = ExtractedProduct()
        product.name = dict["name"] as? String
        product.gtin = (dict["gtin13"] ?? dict["gtin"] ?? dict["gtin12"] ?? dict["gtin8"]) as? String
        product.mpn = dict["mpn"] as? String
        if let brand = dict["brand"] as? [String: Any] {
            product.brand = brand["name"] as? String
        } else {
            product.brand = dict["brand"] as? String
        }
        if let urlString = dict["url"] as? String {
            product.url = URLNormalizer.resolve(urlString, base: baseURL)
        }
        if let image = dict["image"] as? String {
            product.imageURL = URLNormalizer.resolve(image, base: baseURL)
        } else if let images = dict["image"] as? [Any], let first = images.first as? String {
            product.imageURL = URLNormalizer.resolve(first, base: baseURL)
        }

        // Offer price (direct or nested offers).
        if let priceString = dict["price"] as? String ?? (dict["price"] as? Double).map({ String($0) }) {
            product.priceCurrency = dict["priceCurrency"] as? String
            product.price = parseJSONPrice(priceString, currency: product.priceCurrency)
        } else if let priceNumber = dict["price"] as? NSNumber {
            product.priceCurrency = dict["priceCurrency"] as? String
            product.price = Money(amount: priceNumber.decimalValue, currencyCode: product.priceCurrency ?? "PLN")
        }
        if let offers = dict["offers"] {
            for offer in walk(offers, baseURL: baseURL) {
                if product.price == nil, offer.price != nil {
                    product.price = offer.price
                    product.priceCurrency = offer.priceCurrency
                    product.seller = offer.seller
                }
                if product.url == nil { product.url = offer.url }
            }
        }
        if let seller = dict["seller"] as? [String: Any] {
            product.seller = seller["name"] as? String
        }

        guard product.name != nil || product.price != nil else { return nil }
        return product
    }

    private func parseJSONPrice(_ string: String, currency: String?) -> Money? {
        let cleaned = string.replacingOccurrences(of: ",", with: ".")
        guard let decimal = Decimal(string: cleaned) else { return nil }
        return Money(amount: decimal, currencyCode: currency ?? "PLN")
    }
}
