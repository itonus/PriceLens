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
        if let barcode, !barcode.isEmpty { result.append(barcode) }
        let brandModel = [brand, model].compactMap { $0 }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        if !brandModel.isEmpty, brandModel != query { result.append(brandModel) }
        if !query.isEmpty, !result.contains(query) { result.append(query) }
        if let titleHint, !titleHint.isEmpty, !result.contains(titleHint) { result.append(titleHint) }
        return result
    }
}
