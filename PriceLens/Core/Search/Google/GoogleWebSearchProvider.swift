import Foundation

/// Google web search adapter. Best-effort: URLSession → JSON-LD → DOM → (optional) rendered → fallbackOnly.
struct GoogleWebSearchProvider: SearchProvider {
    let id: SearchProviderID = .google

    private let client: HTTPClient
    private let urlBuilder: GoogleSearchURLBuilder
    private let parser: GoogleOfferHTMLParser
    private let config: AppConfig
    private let loader: @Sendable (URL) async throws -> (html: String, status: Int?)
    /// JS-rendered retry. Google's shopping surface ships an empty shell over URLSession
    /// (200 OK, ~90KB, zero prices and zero JSON-LD — verified live), so server HTML alone
    /// can never yield offers; rendering the page is the only way to extract them in-app.
    private let renderedLoader: (@Sendable (URL, TimeInterval) async throws -> String)?

    init(config: AppConfig = .default,
         client: HTTPClient = HTTPClient(),
         urlBuilder: GoogleSearchURLBuilder = GoogleSearchURLBuilder(),
         parser: GoogleOfferHTMLParser = GoogleOfferHTMLParser(),
         loader: (@Sendable (URL) async throws -> (html: String, status: Int?))? = nil,
         renderedLoader: (@Sendable (URL, TimeInterval) async throws -> String)? = nil) {
        self.config = config
        self.client = client
        self.urlBuilder = urlBuilder
        self.parser = parser
        self.loader = loader ?? { url in
            let (data, response) = try await client.get(url)
            return (String(decoding: data, as: UTF8.self), response.statusCode)
        }
        if let renderedLoader {
            self.renderedLoader = renderedLoader
        } else if config.useRenderedFallback {
            self.renderedLoader = { url, timeout in
                try await MainActor.run { WebPageLoader() }
                    .loadRenderedHTML(url, timeout: timeout)
            }
        } else {
            self.renderedLoader = nil
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
            let classification = PageClassifier.classify(html: html, httpStatus: status)

            var serverSummary: String? = nil
            switch classification {
            case .blocked:
                serverSummary = "HTTP \(status ?? 0): blocked page detected"
            case .challenge:
                serverSummary = "Challenge/JS-gated page detected"
            case .consent:
                serverSummary = "Consent page detected"
            case .unknown:
                serverSummary = "Page too small/unknown structure"
            case .content:
                let (candidates, diagnostics) = parser.parse(html: html, baseURL: searchURL)
                if !candidates.isEmpty {
                    return result(.success, candidates,
                                  "\(candidates.count) offers via \(diagnostics.strategyUsed ?? "?")")
                }
                serverSummary = "Parsed 0 offers (strategy: \(diagnostics.strategyUsed ?? "none"))"
            }

            // Server HTML gave us nothing usable — retry once through the rendered loader.
            if let renderedLoader, !Task.isCancelled {
                do {
                    let rendered = try await renderedLoader(searchURL, config.providerTimeout)
                    if case .content = PageClassifier.classify(html: rendered, httpStatus: 200) {
                        let (candidates, diagnostics) = parser.parse(html: rendered, baseURL: searchURL)
                        if !candidates.isEmpty {
                            return result(.success, candidates,
                                          "\(candidates.count) offers via rendered/\(diagnostics.strategyUsed ?? "?")")
                        }
                    }
                    return result(.fallbackOnly, [], "\(serverSummary ?? "no offers"); rendered retry also found none")
                } catch {
                    if Task.isCancelled { return result(.failed, [], "Cancelled") }
                    return result(.fallbackOnly, [], "\(serverSummary ?? "no offers"); rendered retry failed")
                }
            }

            switch classification {
            case .blocked, .challenge, .consent:
                return result(.blocked, [], serverSummary ?? "blocked")
            default:
                return result(.fallbackOnly, [], serverSummary ?? "no offers")
            }
        } catch HTTPError.offline {
            return result(.offline, [], "No network connection")
        } catch {
            if Task.isCancelled { return result(.failed, [], "Cancelled") }
            Log.google.error("Google search failed: \(error.localizedDescription)")
            return result(.failed, [], "Request failed: \(error.localizedDescription)")
        }
    }
}
