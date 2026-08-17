import Foundation

/// Deterministic fixture providers for previews, DEBUG demo mode and UI tests.
/// Never used in Release live scans.
struct FixtureSearchProvider: SearchProvider {
    let id: SearchProviderID
    let scenario: FixtureScenario
    var simulatedDelay: Duration = .milliseconds(400)

    init(id: SearchProviderID, scenario: FixtureScenario) {
        self.id = id
        self.scenario = scenario
    }

    func search(_ request: ProductSearchRequest) async -> ProviderSearchResult {
        try? await Task.sleep(for: simulatedDelay)
        let searchURL: URL = switch id {
        case .ceneo:
            CeneoSearchURLBuilder().searchURL(query: request.query)
        case .google:
            GoogleSearchURLBuilder().searchURL(query: request.query, countryCode: "PL", language: "pl")
        case .allegro:
            AllegroSearchURLBuilder().searchURL(query: request.query)
        }

        switch scenario {
        case .offline:
            return ProviderSearchResult(provider: id, state: .offline, searchURL: searchURL,
                                        offers: [], duration: simulatedDelay, debugSummary: "fixture: offline")
        case .providerFailure:
            if id == .google {
                return ProviderSearchResult(provider: id, state: .blocked, searchURL: searchURL,
                                            offers: [], duration: simulatedDelay, debugSummary: "fixture: blocked")
            }
            return successResult(searchURL: searchURL, offers: Self.allegroOffers)
        case .successfulScan, .noStorePrice:
            let offers: [OfferCandidate] = switch id {
            case .ceneo: Self.ceneoOffers
            case .google: Self.googleOffers
            case .allegro: Self.allegroOffers
            }
            return successResult(searchURL: searchURL, offers: offers)
        }
    }

    private func successResult(searchURL: URL, offers: [OfferCandidate]) -> ProviderSearchResult {
        ProviderSearchResult(provider: id, state: .success, searchURL: searchURL,
                             offers: offers, duration: simulatedDelay, debugSummary: "fixture: success")
    }

    static let ceneoOffers: [OfferCandidate] = [
        OfferCandidate(provider: .ceneo,
                       title: "Sony WH-1000XM6 Bezprzewodowe słuchawki ANC",
                       url: URL(string: "https://www.ceneo.pl/163805693")!,
                       rawPriceText: "1529.00",
                       parsedItemPrice: Money(amount: 1529.00, currencyCode: "PLN"),
                       rawDeliveryText: nil,
                       parsedDeliveryPrice: nil,
                       seller: nil,
                       imageURL: nil,
                       evidence: OfferEvidence(brand: "Sony", extractionStrategy: "product-row"))
    ]

    static let googleOffers: [OfferCandidate] = [
        OfferCandidate(provider: .google,
                       title: "Sony WH-1000XM6 Wireless Noise Cancelling Headphones",
                       url: URL(string: "https://example-shop.pl/sony-wh-1000xm6")!,
                       rawPriceText: "1 549,00 zł",
                       parsedItemPrice: Money(amount: 1549.00, currencyCode: "PLN"),
                       rawDeliveryText: "Darmowa dostawa",
                       parsedDeliveryPrice: Money(amount: 0, currencyCode: "PLN"),
                       seller: "MediaExpert",
                       imageURL: nil,
                       evidence: OfferEvidence(gtin: "5901234123457", mpn: "WH-1000XM6", brand: "Sony",
                                               extractionStrategy: "json-ld", deliveryIsExplicitlyFree: true)),
        OfferCandidate(provider: .google,
                       title: "Słuchawki Sony WH-1000XM6 czarne",
                       url: URL(string: "https://example-electronics.pl/wh1000xm6")!,
                       rawPriceText: "1 619,00 zł",
                       parsedItemPrice: Money(amount: 1619.00, currencyCode: "PLN"),
                       rawDeliveryText: nil,
                       parsedDeliveryPrice: Money(amount: 12.99, currencyCode: "PLN"),
                       seller: "RTV Euro AGD",
                       imageURL: nil,
                       evidence: OfferEvidence(mpn: "WH-1000XM6", brand: "Sony", extractionStrategy: "json-ld"))
    ]

    static let allegroOffers: [OfferCandidate] = [
        OfferCandidate(provider: .allegro,
                       title: "Sony WH-1000XM6 słuchawki bezprzewodowe ANC",
                       url: URL(string: "https://allegro.pl/oferta/12345678901")!,
                       rawPriceText: "1599.00",
                       parsedItemPrice: Money(amount: 1599.00, currencyCode: "PLN"),
                       rawDeliveryText: nil,
                       parsedDeliveryPrice: Money(amount: 0, currencyCode: "PLN"),
                       seller: "AudioSklep",
                       imageURL: nil,
                       evidence: OfferEvidence(brand: "Sony", extractionStrategy: "embedded-state",
                                               deliveryIsExplicitlyFree: true)),
        OfferCandidate(provider: .allegro,
                       title: "Słuchawki Sony podobne do WH-1000XM5",
                       url: URL(string: "https://allegro.pl/oferta/12345678902")!,
                       rawPriceText: "899.00",
                       parsedItemPrice: Money(amount: 899.00, currencyCode: "PLN"),
                       rawDeliveryText: nil,
                       parsedDeliveryPrice: nil,
                       seller: nil,
                       imageURL: nil,
                       evidence: OfferEvidence(extractionStrategy: "article-dom"))
    ]
}
