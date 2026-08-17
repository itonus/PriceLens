import Foundation

/// Token cache for the Allegro `client_credentials` grant.
/// An actor so concurrent provider searches share one token instead of racing to mint several.
actor AllegroTokenStore {
    private var token: String?
    private var expiry: Date = .distantPast
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    private struct TokenResponse: Decodable {
        let access_token: String
        let expires_in: Int
    }

    func validToken() async throws -> String {
        // Refresh a minute early so a token cannot expire mid-request.
        if let token, expiry > Date().addingTimeInterval(60) { return token }

        guard AllegroAPICredentials.isConfigured else { throw AllegroAPIError.notConfigured }

        var request = URLRequest(url: URL(string: "https://allegro.pl/auth/oauth/token?grant_type=client_credentials")!)
        request.httpMethod = "POST"
        let pair = "\(AllegroAPICredentials.clientID):\(AllegroAPICredentials.clientSecret)"
        guard let encoded = pair.data(using: .utf8)?.base64EncodedString() else {
            throw AllegroAPIError.notConfigured
        }
        request.setValue("Basic \(encoded)", forHTTPHeaderField: "Authorization")
        // Mandatory: Allegro blocks the API key outright on calls with a missing/invalid UA.
        request.setValue(AllegroAPICredentials.userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AllegroAPIError.transport }
        guard http.statusCode == 200 else { throw AllegroAPIError.auth(http.statusCode) }

        let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        token = decoded.access_token
        expiry = Date().addingTimeInterval(TimeInterval(decoded.expires_in))
        return decoded.access_token
    }
}

enum AllegroAPIError: Error, Sendable {
    case notConfigured
    case auth(Int)
    case transport
}

/// Allegro offers via the official Open API.
///
/// Preferred over HTML scraping: the public listing page serves a DataDome anti-bot
/// interstitial (verified), so scraping cannot return offers. This returns structured data
/// — title, price, image, seller and product URL — which is what the offer cards need.
struct AllegroAPISearchProvider: SearchProvider {
    let id: SearchProviderID = .allegro

    private let tokenStore: AllegroTokenStore
    private let urlBuilder: AllegroSearchURLBuilder
    private let session: URLSession
    private let config: AppConfig

    init(config: AppConfig = .default,
         tokenStore: AllegroTokenStore = AllegroTokenStore(),
         urlBuilder: AllegroSearchURLBuilder = AllegroSearchURLBuilder(),
         session: URLSession = .shared) {
        self.config = config
        self.tokenStore = tokenStore
        self.urlBuilder = urlBuilder
        self.session = session
    }

    // MARK: - API response shapes (only the fields we actually use)

    private struct ListingResponse: Decodable {
        struct Items: Decodable {
            let promoted: [Item]?
            let regular: [Item]?
        }
        struct Item: Decodable {
            struct Name: Decodable { let name: String? }
            struct Price: Decodable {
                struct Amount: Decodable { let amount: String?; let currency: String? }
                let amount: Amount?
            }
            struct Selling: Decodable { let price: Price? }
            struct Image: Decodable { let url: String? }
            struct Delivery: Decodable {
                struct Cost: Decodable { let amount: String?; let currency: String? }
                let lowestPrice: Cost?
            }
            struct Seller: Decodable { let login: String? }
            struct Product: Decodable { let id: String? }

            let id: String?
            let name: String?
            let sellingMode: Selling?
            let images: [Image]?
            let delivery: Delivery?
            let seller: Seller?
        }
        let items: Items?
    }

    func search(_ request: ProductSearchRequest) async -> ProviderSearchResult {
        let clock = ContinuousClock()
        let start = clock.now
        // Always the human-facing URL, so the fallback action stays correct regardless of API state.
        let searchURL = urlBuilder.searchURL(query: request.query)

        func result(_ state: ProviderSearchState, _ offers: [OfferCandidate], _ summary: String) -> ProviderSearchResult {
            ProviderSearchResult(provider: .allegro, state: state, searchURL: searchURL,
                                 offers: offers, duration: start.duration(to: clock.now),
                                 debugSummary: summary)
        }

        guard AllegroAPICredentials.isConfigured else {
            return result(.fallbackOnly, [], "Allegro API credentials not configured")
        }

        do {
            let token = try await tokenStore.validToken()

            var components = URLComponents(string: "https://api.allegro.pl/offers/listing")!
            components.queryItems = [
                URLQueryItem(name: "phrase", value: request.query),
                URLQueryItem(name: "limit", value: "20"),
                URLQueryItem(name: "sort", value: "+withDeliveryPrice")
            ]
            guard let url = components.url else { return result(.failed, [], "Bad listing URL") }

            var apiRequest = URLRequest(url: url, timeoutInterval: config.providerTimeout)
            apiRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            apiRequest.setValue("application/vnd.allegro.public.v1+json", forHTTPHeaderField: "Accept")
            // Mandatory: Allegro blocks the API key outright on calls with a missing/invalid UA.
            apiRequest.setValue(AllegroAPICredentials.userAgent, forHTTPHeaderField: "User-Agent")

            let (data, response) = try await session.data(for: apiRequest)
            guard let http = response as? HTTPURLResponse else { return result(.failed, [], "Invalid response") }
            guard http.statusCode == 200 else {
                // 403 here is normally `VerificationRequired`: valid credentials, but Allegro
                // gates offer search behind manual application verification. Surface that
                // specifically — it is an account state to resolve, not a bug to retry.
                var summary = "Listing HTTP \(http.statusCode)"
                if http.statusCode == 403,
                   let body = String(data: data, encoding: .utf8),
                   body.contains("VerificationRequired") {
                    summary = "Allegro app not verified — offer search requires verification"
                }
                return result(http.statusCode == 401 || http.statusCode == 403 ? .blocked : .failed,
                              [], summary)
            }

            let decoded = try JSONDecoder().decode(ListingResponse.self, from: data)
            let items = (decoded.items?.promoted ?? []) + (decoded.items?.regular ?? [])
            let candidates = items.compactMap(candidate(from:))

            if candidates.isEmpty {
                return result(.fallbackOnly, [], "API returned 0 usable offers")
            }
            return result(.success, candidates, "\(candidates.count) offers via allegro-api")
        } catch AllegroAPIError.notConfigured {
            return result(.fallbackOnly, [], "Allegro API credentials not configured")
        } catch AllegroAPIError.auth(let status) {
            return result(.blocked, [], "Allegro auth failed (HTTP \(status))")
        } catch let error as URLError where error.code == .notConnectedToInternet {
            return result(.offline, [], "No network connection")
        } catch {
            if Task.isCancelled { return result(.failed, [], "Cancelled") }
            Log.allegro.error("Allegro API search failed: \(error.localizedDescription)")
            return result(.failed, [], "Request failed: \(error.localizedDescription)")
        }
    }

    private func candidate(from item: ListingResponse.Item) -> OfferCandidate? {
        guard let id = item.id,
              let title = item.name,
              let offerURL = URL(string: "https://allegro.pl/oferta/\(id)"),
              let rawAmount = item.sellingMode?.price?.amount?.amount else { return nil }

        let currency = item.sellingMode?.price?.amount?.currency ?? "PLN"
        guard let amount = Decimal(string: rawAmount, locale: Locale(identifier: "en_US")) else { return nil }
        let itemPrice = Money(amount: amount, currencyCode: currency)

        // Delivery is only reported when the API states it — never assume free shipping.
        var deliveryPrice: Money? = nil
        if let cost = item.delivery?.lowestPrice,
           let rawDelivery = cost.amount,
           let deliveryAmount = Decimal(string: rawDelivery, locale: Locale(identifier: "en_US")) {
            deliveryPrice = Money(amount: deliveryAmount, currencyCode: cost.currency ?? currency)
        }

        return OfferCandidate(
            provider: .allegro,
            title: title,
            url: offerURL,
            rawPriceText: rawAmount,
            parsedItemPrice: itemPrice,
            rawDeliveryText: item.delivery?.lowestPrice?.amount,
            parsedDeliveryPrice: deliveryPrice,
            seller: item.seller?.login,
            imageURL: item.images?.first?.url.flatMap(URL.init(string:)),
            evidence: OfferEvidence(gtin: nil, mpn: nil, brand: nil, extractionStrategy: "allegro-api")
        )
    }
}
