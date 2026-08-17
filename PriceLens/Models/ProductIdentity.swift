import Foundation

/// Canonical in-memory identity of a scanned product.
struct ProductIdentity: Sendable, Hashable {
    var barcode: String?
    var brand: String?
    var model: String?
    var titleHint: String?
    var rawRecognizedText: [String]
    var query: String

    /// Ordered query strategy.
    ///
    /// A barcode identifies exactly one product, so when we have one it is the *only* thing
    /// searched. Name-based queries were tried and dropped: a product database returns the
    /// manufacturer-language name, retailers list their own wording, and the looser the phrase
    /// the more it returns neighbouring variants — a different pack size, a different flavour —
    /// which is worse than an honest empty result. Text queries are for when there is no
    /// barcode at all (manual entry, or a label with no code).
    var queryCandidates: [String] {
        if let barcode, !barcode.isEmpty {
            var codes = [barcode]
            // A UPC-A code is normalized to EAN-13 by prefixing a zero, but retailers index
            // whichever form is printed on the pack. Try the 12-digit original too, otherwise a
            // product listed under its UPC-A code is never found. Same product either way.
            if barcode.count == 13, barcode.hasPrefix("0"), barcode.allSatisfy(\.isNumber) {
                codes.append(String(barcode.dropFirst()))
            }
            return codes
        }

        var result: [String] = []
        let brandModel = [brand, model].compactMap { $0 }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        if !brandModel.isEmpty, brandModel != query { result.append(brandModel) }
        if !query.isEmpty, !result.contains(query) { result.append(query) }
        if let titleHint, !titleHint.isEmpty, !result.contains(titleHint) { result.append(titleHint) }

        return result
    }
}
