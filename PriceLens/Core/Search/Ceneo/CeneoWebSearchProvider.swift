import Foundation

/// Ceneo price-comparison adapter. Best-effort, like every web provider here.
///
/// Ceneo serves complete server-rendered listings — unlike Google (JS-gated) and Allegro
/// (anti-bot interstitial) — so it is currently the one source that yields real in-app offers.
/// Barcode phrases work directly, which suits the scanner-first flow.
struct CeneoWebSearchProvider: SearchProvider {
    let id: SearchProviderID = .ceneo

    private let client: HTTPClient
    private let urlBuilder: CeneoSearchURLBuilder
    private let parser: CeneoOfferHTMLParser
    private let loader: @Sendable (URL) async throws -> (html: String, status: Int?)

    init(config: AppConfig = .default,
         client: HTTPClient = HTTPClient(),
         urlBuilder: CeneoSearchURLBuilder = CeneoSearchURLBuilder(),
         parser: CeneoOfferHTMLParser = CeneoOfferHTMLParser(),
         loader: (@Sendable (URL) async throws -> (html: String, status: Int?))? = nil) {
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
        let searchURL = urlBuilder.searchURL(query: request.query)

        func result(_ state: ProviderSearchState, _ offers: [OfferCandidate], _ summary: String) -> ProviderSearchResult {
            ProviderSearchResult(provider: .ceneo, state: state, searchURL: searchURL,
                                 offers: offers, duration: start.duration(to: clock.now),
                                 debugSummary: summary)
        }

        do {
            let (html, status) = try await loader(searchURL)
            switch PageClassifier.classify(html: html, httpStatus: status) {
            case .blocked:
                return result(.blocked, [], "HTTP \(status ?? 0): blocked page detected")
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
            Log.ceneo.error("Ceneo search failed: \(error.localizedDescription)")
            return result(.failed, [], "Request failed: \(error.localizedDescription)")
        }
    }
}
