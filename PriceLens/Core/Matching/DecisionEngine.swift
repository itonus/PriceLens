import Foundation

/// Pure, testable purchase decision. No networking, no UI strings, no side effects.
struct DecisionEngine: Sendable {

    let goodThreshold: Decimal
    let fairThreshold: Decimal

    init(config: AppConfig = .default) {
        self.goodThreshold = config.goodThreshold
        self.fairThreshold = config.fairThreshold
    }

    init(goodThreshold: Decimal = 1.05, fairThreshold: Decimal = 1.10) {
        self.goodThreshold = goodThreshold
        self.fairThreshold = fairThreshold
    }

    func decision(storePrice: Money?, offers: [Offer]) -> PurchaseDecision {
        // Comparable = recommendation-eligible confidence + valid price.
        let comparable = offers.filter { $0.matchConfidence.isRecommendationEligible }

        guard let best = comparable.min(by: { $0.comparisonPrice.amount < $1.comparisonPrice.amount }) else {
            return .empty
        }

        guard let storePrice else {
            // No store price: still surface the best offer, but no recommendation.
            return PurchaseDecision(recommendation: nil, bestOffer: best,
                                    absoluteSaving: nil, percentSaving: nil)
        }

        guard storePrice.isCompatible(with: best.comparisonPrice), storePrice.amount > 0 else {
            return PurchaseDecision(recommendation: nil, bestOffer: best,
                                    absoluteSaving: nil, percentSaving: nil)
        }

        let bestPrice = best.comparisonPrice
        let ratio = storePrice.amount / bestPrice.amount
        let saving = storePrice - bestPrice
        let percent = bestPrice.percentSaved(relativeTo: storePrice)

        let recommendation: PurchaseRecommendation
        if ratio <= goodThreshold {
            recommendation = .goodHere
        } else if ratio <= fairThreshold {
            recommendation = .fairPrice
        } else {
            recommendation = .betterOnline
        }

        return PurchaseDecision(recommendation: recommendation,
                                bestOffer: best,
                                absoluteSaving: saving.amount > 0 ? saving : nil,
                                percentSaving: percent.flatMap { $0 > 0 ? $0 : nil })
    }
}
