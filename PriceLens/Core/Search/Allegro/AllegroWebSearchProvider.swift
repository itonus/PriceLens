import Foundation

/// Allegro web search adapter. Best-effort: URLSession → JSON-LD → embedded state → DOM → fallbackOnly.
/// Does NOT use the retired public listing REST API and never solves anti-bot challenges.
struct AllegroWebSearchProvider: SearchProvider {
    let id: SearchProviderID = .allegro

    private let urlBuilder: AllegroSearchURLBuilder
    private let parser: AllegroOfferHTMLParser
    private let loader: @Sendable (URL) async throws -> (html: String, status: Int?)

    init(config: AppConfig = .default,
         urlBuilder: AllegroSearchURLBuilder = AllegroSearchURLBuilder(),
         parser: AllegroOfferHTMLParser = AllegroOfferHTMLParser(),
         loader: (@Sendable (URL) async throws -> (html: String, status: Int?))? = nil) {
        let client = HTTPClient(config: config)
        self.urlBuilder = urlBuilder
        self.parser = parser
        self.loader = loader ?? { url in
            let (data, response) = try await client.get(url)
            return (String(decoding: data, as: UTF8.self), response.statusCode)
        }
    }

    func search(_ request: ProductSearchRequest) async -> ProviderSearchResult {
        let clock = ContinuousClock()
        let start = clock.now
        let searchURL = urlBuilder.searchURL(query: request.query)

        func result(_ state: ProviderSearchState, _ offers: [OfferCandidate], _ summary: String) -> ProviderSearchResult {
            ProviderSearchResult(provider: .allegro, state: state, searchURL: searchURL,
                                 offers: offers, duration: start.duration(to: clock.now),
                                 debugSummary: summary)
        }

        do {
            let (html, status) = try await loader(searchURL)
            switch PageClassifier.classify(html: html, httpStatus: status) {
            case .blocked:
                return result(.blocked, [], "HTTP \(status ?? 0): anti-bot interstitial (e.g. DataDome)")
            case .challenge:
                return result(.blocked, [], "Challenge page detected")
            case .consent:
                return result(.blocked, [], "Consent page detected")
            case .unknown:
                return result(.fallbackOnly, [], "Page too small/unknown structure")
            case .content:
                break
            }

            let (candidates, diagnostics) = parser.parse(html: html, baseURL: searchURL)
            if candidates.isEmpty {
                return result(.fallbackOnly, [],
                              "Parsed 0 offers (strategy: \(diagnostics.strategyUsed ?? "none"))")
            }
            return result(.success, candidates,
                          "\(candidates.count) offers via \(diagnostics.strategyUsed ?? "?")")
        } catch HTTPError.offline {
            return result(.offline, [], "No network connection")
        } catch {
            if Task.isCancelled { return result(.failed, [], "Cancelled") }
            Log.allegro.error("Allegro search failed: \(error.localizedDescription)")
            return result(.failed, [], "Request failed: \(error.localizedDescription)")
        }
    }
}
