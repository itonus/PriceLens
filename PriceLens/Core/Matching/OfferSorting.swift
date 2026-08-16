import Foundation

enum OfferSortOrder: String, CaseIterable, Sendable {
    case bestMatch
    case lowestItemPrice
    case lowestTotal
}

/// Unified offer ordering across providers.
/// Default: confidence first, then known total ascending, then item price, then provider order.
enum OfferSorting {

    static func sort(_ offers: [Offer],
                     order: OfferSortOrder,
                     providerOrder: [SearchProviderID: Int] = [:]) -> [Offer] {
        offers
            .enumerated()
            .sorted { lhs, rhs in
                compare(lhs.element, lhs.offset, rhs.element, rhs.offset, order: order, providerOrder: providerOrder)
            }
            .map(\.element)
    }

    private static func compare(_ a: Offer, _ indexA: Int,
                                _ b: Offer, _ indexB: Int,
                                order: OfferSortOrder,
                                providerOrder: [SearchProviderID: Int]) -> Bool {
        switch order {
        case .bestMatch:
            // 1. exact/high before medium/low — a cheaper medium must not outrank an exact.
            let aEligible = a.matchConfidence.isRecommendationEligible
            let bEligible = b.matchConfidence.isRecommendationEligible
            if aEligible != bEligible { return aEligible }
            if a.matchConfidence != b.matchConfidence { return a.matchConfidence > b.matchConfidence }

            // 2. calculable total delivered price ascending
            if let ta = a.totalPrice, let tb = b.totalPrice, ta.amount != tb.amount {
                return ta.amount < tb.amount
            }
            // 3. known total beats unknown shipping at equal confidence
            if (a.totalPrice != nil) != (b.totalPrice != nil) { return a.totalPrice != nil }
            // 4. item price ascending
            if a.itemPrice.amount != b.itemPrice.amount { return a.itemPrice.amount < b.itemPrice.amount }

        case .lowestItemPrice:
            if a.itemPrice.amount != b.itemPrice.amount { return a.itemPrice.amount < b.itemPrice.amount }

        case .lowestTotal:
            if let ta = a.totalPrice, let tb = b.totalPrice, ta.amount != tb.amount {
                return ta.amount < tb.amount
            }
            if (a.totalPrice != nil) != (b.totalPrice != nil) { return a.totalPrice != nil }
            if a.itemPrice.amount != b.itemPrice.amount { return a.itemPrice.amount < b.itemPrice.amount }
        }

        // Final tie-breakers: provider order, then original index.
        let pa = providerOrder[a.provider] ?? 0
        let pb = providerOrder[b.provider] ?? 0
        if pa != pb { return pa < pb }
        return indexA < indexB
    }
}
