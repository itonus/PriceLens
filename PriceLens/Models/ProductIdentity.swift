import Foundation

/// Canonical in-memory identity of a scanned product.
struct ProductIdentity: Sendable, Hashable {
    var barcode: String?
    var brand: String?
    var model: String?
    var titleHint: String?
    var rawRecognizedText: [String]
    var query: String

    /// Ordered query strategy: barcode first, then brand+model, then title hint.
    var queryCandidates: [String] {
        var result: [String] = []
        if let barcode, !barcode.isEmpty {
            result.append(barcode)
            // A UPC-A code is normalized to EAN-13 by prefixing a zero, but retailers index
            // whichever form is printed on the pack. Try the 12-digit original too, otherwise a
            // product listed under its UPC-A code is never found.
            if barcode.count == 13, barcode.hasPrefix("0"), barcode.allSatisfy(\.isNumber) {
                result.append(String(barcode.dropFirst()))
            }
        }
        let brandModel = [brand, model].compactMap { $0 }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        if !brandModel.isEmpty, brandModel != query { result.append(brandModel) }
        if !query.isEmpty, !result.contains(query) { result.append(query) }
        if let titleHint, !titleHint.isEmpty, !result.contains(titleHint) { result.append(titleHint) }

        // Last resort: a shortened phrase. A product database returns the name in the
        // manufacturer's language ("Haribo - Primavera Erdbeeren"), which a local retailer may
        // not list verbatim — Ceneo finds nothing for that but three offers for
        // "haribo primavera". Keeping the leading, most distinctive words is a better bet than
        // giving up, and it runs only after every exact form has already missed.
        for phrase in result.filter({ $0 != barcode }) {
            let words = phrase
                .split(whereSeparator: { $0.isWhitespace })
                .map(String.init)
                .filter { $0.count > 1 || $0.rangeOfCharacter(from: .alphanumerics) != nil }
                .filter { $0 != "-" }
            guard words.count > 2 else { continue }
            let relaxed = words.prefix(2).joined(separator: " ")
            if !relaxed.isEmpty, !result.contains(relaxed) { result.append(relaxed) }
        }
        return result
    }
}
