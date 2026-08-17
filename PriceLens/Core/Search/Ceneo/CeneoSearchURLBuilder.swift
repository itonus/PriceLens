import Foundation

/// Canonical Ceneo search URL. All URL construction lives here.
struct CeneoSearchURLBuilder: Sendable {

    /// Ceneo uses a path-based search (`/szukaj-<phrase>`) with `+` for spaces, and 301-redirects
    /// to a category-scoped URL. Both barcodes and free text work as the phrase.
    func searchURL(query: String) -> URL {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-.")
        let encoded = trimmed
            .replacingOccurrences(of: " ", with: "+")
            .addingPercentEncoding(withAllowedCharacters: allowed.union(CharacterSet(charactersIn: "+")))
            ?? trimmed
        return URL(string: "https://www.ceneo.pl/szukaj-\(encoded)")
            ?? URL(string: "https://www.ceneo.pl")!
    }
}
