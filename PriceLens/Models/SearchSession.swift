import Foundation

/// One user scan session: identity locked, search executed, decision computed.
struct SearchSession: Sendable, Identifiable {
    let id: UUID
    let startedAt: Date
    var identity: ProductIdentity
    var storePrice: Money?
    var activeQuery: String

    init(id: UUID = UUID(), startedAt: Date = Date(), identity: ProductIdentity, storePrice: Money?, activeQuery: String) {
        self.id = id
        self.startedAt = startedAt
        self.identity = identity
        self.storePrice = storePrice
        self.activeQuery = activeQuery
    }
}

/// Final purchase recommendation shown to the user.
enum PurchaseRecommendation: String, Sendable, Codable {
    case goodHere
    case fairPrice
    case betterOnline
    case compareCarefully
}

/// Output of the decision engine.
struct PurchaseDecision: Sendable, Hashable {
    var recommendation: PurchaseRecommendation?
    var bestOffer: Offer?
    var absoluteSaving: Money?
    var percentSaving: Decimal?

    static let empty = PurchaseDecision(recommendation: nil, bestOffer: nil, absoluteSaving: nil, percentSaving: nil)
}
