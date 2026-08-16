import Foundation
import Testing
@testable import PriceLens

@Suite("DecisionEngine")
struct DecisionEngineTests {

    let engine = DecisionEngine() // 1.05 / 1.10 thresholds

    func offer(price: String, confidence: MatchConfidence, delivery: Decimal? = 0, currency: String = "PLN") -> Offer {
        let item = Money(amount: Decimal(string: price)!, currencyCode: currency)
        let deliveryMoney = delivery.map { Money(amount: $0, currencyCode: currency) }
        return Offer(id: UUID().uuidString, provider: .google, title: "T",
                     productURL: URL(string: "https://example.com/x")!,
                     imageURL: nil, itemPrice: item,
                     deliveryPrice: deliveryMoney,
                     totalPrice: deliveryMoney.map { Money(amount: item.amount + $0.amount, currencyCode: currency) },
                     seller: nil, matchConfidence: confidence, extractionConfidence: 0.9)
    }

    @Test func noStorePriceNoRecommendation() {
        let decision = engine.decision(storePrice: nil, offers: [offer(price: "100", confidence: .exact)])
        #expect(decision.recommendation == nil)
        #expect(decision.bestOffer != nil)
    }

    @Test func noOffers() {
        let decision = engine.decision(storePrice: Money(amount: 100, currencyCode: "PLN"), offers: [])
        #expect(decision.recommendation == nil)
        #expect(decision.bestOffer == nil)
    }

    @Test func goodHereAtThreshold() {
        // store 1049 vs best 999 -> ratio 1.05 -> good
        let store = Money(amount: Decimal(string: "1048.95")!, currencyCode: "PLN")
        let decision = engine.decision(storePrice: store, offers: [offer(price: "999", confidence: .high)])
        #expect(decision.recommendation == .goodHere)
    }

    @Test func fairBetweenThresholds() {
        // store 1060 vs best 999 -> ratio ~1.061 -> fair
        let store = Money(amount: Decimal(string: "1060")!, currencyCode: "PLN")
        let decision = engine.decision(storePrice: store, offers: [offer(price: "999", confidence: .exact)])
        #expect(decision.recommendation == .fairPrice)
    }

    @Test func betterOnlineBeyondThreshold() {
        // store 1799 vs best 1549 -> ratio 1.16 -> better online, saving 250 / 13.9%
        let store = Money(amount: Decimal(string: "1799")!, currencyCode: "PLN")
        let decision = engine.decision(storePrice: store, offers: [offer(price: "1549", confidence: .exact)])
        #expect(decision.recommendation == .betterOnline)
        #expect(decision.absoluteSaving?.amount == 250)
        #expect(decision.percentSaving != nil)
    }

    @Test func mediumAndLowExcludedFromRecommendation() {
        let store = Money(amount: 1000, currencyCode: "PLN")
        let decision = engine.decision(storePrice: store,
                                       offers: [offer(price: "500", confidence: .medium),
                                                offer(price: "400", confidence: .low)])
        #expect(decision.recommendation == nil)
        #expect(decision.bestOffer == nil)
    }

    @Test func unknownDeliveryUsesItemPrice() {
        let store = Money(amount: 1000, currencyCode: "PLN")
        let decision = engine.decision(storePrice: store, offers: [offer(price: "900", confidence: .exact, delivery: nil)])
        #expect(decision.bestOffer?.comparisonPrice.amount == 900)
    }

    @Test func currencyMismatchNoRecommendation() {
        let store = Money(amount: 1000, currencyCode: "PLN")
        let decision = engine.decision(storePrice: store,
                                       offers: [offer(price: "100", confidence: .exact, currency: "EUR")])
        #expect(decision.recommendation == nil)
    }
}

@Suite("OfferSorting")
struct OfferSortingTests {

    func offer(id: String, price: Decimal, confidence: MatchConfidence, delivery: Decimal? = 0, provider: SearchProviderID = .google) -> Offer {
        let item = Money(amount: price, currencyCode: "PLN")
        let deliveryMoney = delivery.map { Money(amount: $0, currencyCode: "PLN") }
        return Offer(id: id, provider: provider, title: id,
                     productURL: URL(string: "https://example.com/\(id)")!,
                     imageURL: nil, itemPrice: item, deliveryPrice: deliveryMoney,
                     totalPrice: deliveryMoney.map { Money(amount: price + $0, currencyCode: "PLN") },
                     seller: nil, matchConfidence: confidence, extractionConfidence: 0.9)
    }

    @Test func cheaperMediumDoesNotOutrankExact() {
        let exact = offer(id: "exact", price: 1000, confidence: .exact)
        let medium = offer(id: "medium", price: 900, confidence: .medium)
        let sorted = OfferSorting.sort([medium, exact], order: .bestMatch)
        #expect(sorted.first?.id == "exact")
    }

    @Test func knownTotalBeatsUnknownShipping() {
        let known = offer(id: "known", price: 1000, confidence: .high, delivery: 10)
        let unknown = offer(id: "unknown", price: 990, confidence: .high, delivery: nil)
        let sorted = OfferSorting.sort([unknown, known], order: .bestMatch)
        #expect(sorted.first?.id == "known")
    }

    @Test func tieBreaksByItemPrice() {
        let a = offer(id: "a", price: 1000, confidence: .high)
        let b = offer(id: "b", price: 900, confidence: .high)
        let sorted = OfferSorting.sort([a, b], order: .bestMatch)
        #expect(sorted.map(\.id) == ["b", "a"])
    }

    @Test func lowestItemPriceOrder() {
        let a = offer(id: "a", price: 1000, confidence: .exact)
        let b = offer(id: "b", price: 900, confidence: .low)
        let sorted = OfferSorting.sort([a, b], order: .lowestItemPrice)
        #expect(sorted.map(\.id) == ["b", "a"])
    }

    @Test func providersNotMergedAcrossSources() {
        let g = offer(id: "g", price: 100, confidence: .high, provider: .google)
        let a = offer(id: "a", price: 100, confidence: .high, provider: .allegro)
        let sorted = OfferSorting.sort([g, a], order: .bestMatch,
                                       providerOrder: [.google: 0, .allegro: 1])
        #expect(sorted.count == 2)
        #expect(sorted.map(\.id) == ["g", "a"])
    }
}
