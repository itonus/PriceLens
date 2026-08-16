import Foundation
import SwiftData

@Model
final class ScanHistoryRecord {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var query: String
    var barcode: String?
    var storePriceAmount: Decimal?
    var storePriceCurrency: String?
    var bestPriceAmount: Decimal?
    var bestPriceCurrency: String?
    var decisionRawValue: String?
    var providerSummary: String?

    init(id: UUID = UUID(),
         createdAt: Date = Date(),
         query: String,
         barcode: String? = nil,
         storePrice: Money? = nil,
         bestPrice: Money? = nil,
         decisionRawValue: String? = nil,
         providerSummary: String? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.query = query
        self.barcode = barcode
        self.storePriceAmount = storePrice?.amount
        self.storePriceCurrency = storePrice?.currencyCode
        self.bestPriceAmount = bestPrice?.amount
        self.bestPriceCurrency = bestPrice?.currencyCode
        self.decisionRawValue = decisionRawValue
        self.providerSummary = providerSummary
    }

    var storePrice: Money? {
        guard let storePriceAmount, let storePriceCurrency else { return nil }
        return Money(amount: storePriceAmount, currencyCode: storePriceCurrency)
    }

    var bestPrice: Money? {
        guard let bestPriceAmount, let bestPriceCurrency else { return nil }
        return Money(amount: bestPriceAmount, currencyCode: bestPriceCurrency)
    }
}
