import Foundation

/// Google web search adapter. Best-effort: URLSession → JSON-LD → DOM → (optional) rendered → fallbackOnly.
struct GoogleWebSearchProvider: SearchProvider {
    let id: SearchProviderID = .google

    private let client: HTTPClient
    private let urlBuilder: GoogleSearchURLBuilder
    private let parser: GoogleOfferHTMLParser
    private let config: AppConfig
    private let loader: @Sendable (URL) async throws -> (html: String, status: Int?)

    init(config: AppConfig = .default,
         client: HTTPClient = HTTPClient(),
         urlBuilder: GoogleSearchURLBuilder = GoogleSearchURLBuilder(),
         parser: GoogleOfferHTMLParser = GoogleOfferHTMLParser(),
         loader: (@Sendable (URL) async throws -> (html: String, status: Int?))? = nil) {
        self.config = config
        self.client = client
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
        let searchURL = urlBuilder.searchURL(query: request.query,
                                             countryCode: request.countryCode,
                                             language: request.preferredLanguage)

        func result(_ state: ProviderSearchState, _ offers: [OfferCandidate], _ summary: String) -> ProviderSearchResult {
            ProviderSearchResult(provider: .google, state: state, searchURL: searchURL,
                                 offers: offers, duration: start.duration(to: clock.now),
                                 debugSummary: summary)
        }

        do {
            let (html, status) = try await loader(searchURL)
            switch PageClassifier.classify(html: html, httpStatus: status) {
            case .blocked:
                return result(.blocked, [], "HTTP \(status ?? 0): blocked page detected")
            case .challenge:
                return result(.blocked, [], "Challenge/JS-gated page detected")
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
            Log.google.error("Google search failed: \(error.localizedDescription)")
            return result(.failed, [], "Request failed: \(error.localizedDescription)")
        }
    }
}
