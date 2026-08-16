import Foundation

/// Canonical consumer Allegro search URL. All URL construction lives here.
struct AllegroSearchURLBuilder: Sendable {

    func searchURL(query: String) -> URL {
        var components = URLComponents(string: "https://allegro.pl/listing")!
        components.queryItems = [URLQueryItem(name: "string", value: query)]
        return components.url!
    }
}
