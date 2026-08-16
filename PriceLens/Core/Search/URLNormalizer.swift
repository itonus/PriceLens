import Foundation

/// Canonicalizes provider URLs for deduplication: strips tracking params, resolves relatives.
enum URLNormalizer {

    private static let trackingParameters: Set<String> = [
        "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
        "gclid", "gad_source", "fbclid", "ref", "source", "ved", "ei", "sa", "usg"
    ]

    static func normalize(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        if let items = components.queryItems {
            let kept = items.filter { !trackingParameters.contains($0.name.lowercased()) }
            components.queryItems = kept.isEmpty ? nil : kept
        }
        components.fragment = nil
        if components.scheme == "http" { components.scheme = "https" }
        return components.url ?? url
    }

    static func resolve(_ href: String, base: URL) -> URL? {
        guard let url = URL(string: href, relativeTo: base) else { return nil }
        return url.absoluteURL
    }

    /// Extracts the real destination from Google redirect links (/url?q=...).
    static func unwrapGoogleRedirect(_ url: URL) -> URL {
        guard let host = url.host, host.contains("google."),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let q = components.queryItems?.first(where: { $0.name == "q" })?.value,
              let destination = URL(string: q) else { return url }
        return destination
    }
}
