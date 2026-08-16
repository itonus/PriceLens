import Foundation
import SwiftData

/// Local scan-history repository. All access on MainActor (history is UI-visible data).
@MainActor
final class HistoryRepository {
    private let context: ModelContext
    private let limit: Int

    init(context: ModelContext, limit: Int = AppConfig.default.historyLimit) {
        self.context = context
        self.limit = limit
    }

    @discardableResult
    func save(query: String,
              barcode: String?,
              storePrice: Money?,
              bestPrice: Money?,
              recommendation: PurchaseRecommendation?,
              providerSummary: String?) -> ScanHistoryRecord {
        let record = ScanHistoryRecord(
            query: query,
            barcode: barcode,
            storePrice: storePrice,
            bestPrice: bestPrice,
            decisionRawValue: recommendation?.rawValue,
            providerSummary: providerSummary
        )
        context.insert(record)
        enforceLimit()
        try? context.save()
        return record
    }

    func fetchAll() -> [ScanHistoryRecord] {
        let descriptor = FetchDescriptor<ScanHistoryRecord>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func delete(_ record: ScanHistoryRecord) {
        context.delete(record)
        try? context.save()
    }

    func clearAll() {
        for record in fetchAll() { context.delete(record) }
        try? context.save()
    }

    private func enforceLimit() {
        let all = fetchAll()
        guard all.count > limit else { return }
        for record in all.suffix(from: limit) { // fetchAll is newest-first; suffix = oldest
            context.delete(record)
        }
    }
}
