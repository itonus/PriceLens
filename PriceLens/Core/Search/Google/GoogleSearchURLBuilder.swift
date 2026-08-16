import Foundation

/// Canonical Google Shopping-oriented search URL. All URL construction lives here.
struct GoogleSearchURLBuilder: Sendable {

    func searchURL(query: String, countryCode: String, language: String) -> URL {
        var components = URLComponents(string: "https://www.google.pl/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "tbm", value: "shop"),
            URLQueryItem(name: "hl", value: language),
            URLQueryItem(name: "gl", value: countryCode.lowercased()),
            URLQueryItem(name: "num", value: "20")
        ]
        return components.url!
    }
}
