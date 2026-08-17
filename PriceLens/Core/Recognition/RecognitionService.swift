import Foundation
import CoreGraphics

/// Turns raw scanner observations into a stable, lockable scan candidate.
/// Performs no web search.
@MainActor
final class RecognitionService {
    struct ScanCandidate: Sendable {
        let identity: ProductIdentity
        let storePrice: Money?
        let barcodeValue: String?
        /// True when several prices competed; UI should expose price chips for correction.
        let priceWasAmbiguous: Bool
    }

    enum Status: Sendable, Equatable {
        case pointAtProduct
        case barcodeFound
        case readingLabel
        case tapAProduct
    }

    struct ProcessResult {
        var status: Status
        var lock: ScanCandidate?
        /// Barcode values currently competing (for overlay emphasis).
        var candidateBarcodes: [String]
    }

    private let config: AppConfig
    private let queryBuilder: ProductQueryBuilder

    /// value -> first seen instant (lock tracking)
    private var barcodeFirstSeen: [String: ContinuousClock.Instant] = [:]
    private var modelFirstSeen: [String: ContinuousClock.Instant] = [:]

    init(config: AppConfig = .default, queryBuilder: ProductQueryBuilder = ProductQueryBuilder()) {
        self.config = config
        self.queryBuilder = queryBuilder
    }

    func reset() {
        barcodeFirstSeen.removeAll()
        modelFirstSeen.removeAll()
    }

    // MARK: - Frame processing

    func process(_ observations: [ScannerObservation]) -> ProcessResult {
        let now = ContinuousClock.now
        let barcodes = normalizedBarcodes(from: observations)
        let texts = observations.compactMap { obs -> String? in
            if case .text(let value) = obs.kind { return value }
            return nil
        }
        let prices = observations.filter { obs in
            if case .price = obs.kind { return true }
            return false
        }

        // Prune trackers for values no longer visible.
        let visibleValues = Set(barcodes.map(\.value))
        barcodeFirstSeen = barcodeFirstSeen.filter { visibleValues.contains($0.key) }

        if barcodes.isEmpty {
            // Text-only path: lock on a strong model token after stabilization.
            let result = queryBuilder.build(barcode: nil, recognizedText: texts)
            if let model = result.model {
                // Seed tracking from the source observations' firstSeen.
                let firstObservation = observations
                    .filter { obs in
                        if case .text(let value) = obs.kind { return value.contains(model) || model.contains(value) }
                        return false
                    }
                    .map(\.firstSeen)
                    .min()
                let tracked = modelFirstSeen[model]
                let first = [tracked, firstObservation].compactMap { $0 }.min() ?? now
                modelFirstSeen[model] = first
                if now - first >= .milliseconds(Int(config.barcodeLockInterval * 2 * 1000)) {
                    let identity = ProductIdentity(barcode: nil, brand: result.brand, model: result.model,
                                                   titleHint: result.titleHint, rawRecognizedText: texts,
                                                   query: result.query)
                    let (price, ambiguous) = selectPrice(from: prices, near: nil)
                    return ProcessResult(status: .readingLabel,
                                         lock: ScanCandidate(identity: identity, storePrice: price,
                                                             barcodeValue: nil, priceWasAmbiguous: ambiguous),
                                         candidateBarcodes: [])
                }
                return ProcessResult(status: .readingLabel, lock: nil, candidateBarcodes: [])
            }
            return ProcessResult(status: texts.isEmpty ? .pointAtProduct : .readingLabel,
                                 lock: nil, candidateBarcodes: [])
        }

        if barcodes.count > 1 {
            return ProcessResult(status: .tapAProduct, lock: nil,
                                 candidateBarcodes: barcodes.map(\.value))
        }

        // Exactly one barcode: stabilize then lock. Seeded from the observation's firstSeen.
        let target = barcodes[0]
        let tracked = barcodeFirstSeen[target.value]
        let first = [tracked, target.observation.firstSeen].compactMap { $0 }.min() ?? now
        barcodeFirstSeen[target.value] = first

        guard now - first >= .milliseconds(Int(config.barcodeLockInterval * 1000)) else {
            return ProcessResult(status: .barcodeFound, lock: nil, candidateBarcodes: [target.value])
        }

        let candidate = buildCandidate(barcode: target, observations: observations, texts: texts, prices: prices)
        return ProcessResult(status: .barcodeFound, lock: candidate, candidateBarcodes: [target.value])
    }

    // MARK: - Manual selection (tap-to-select)

    func lock(observation: ScannerObservation, in observations: [ScannerObservation]) -> ScanCandidate? {
        let texts = observations.compactMap { obs -> String? in
            if case .text(let value) = obs.kind { return value }
            return nil
        }
        let prices = observations.filter { obs in
            if case .price = obs.kind { return true }
            return false
        }

        switch observation.kind {
        case .barcode(let value, let symbology):
            guard let normalized = BarcodeNormalizer.normalize(value, symbology: symbology),
                  normalized.isCheckDigitValid else { return nil }
            return buildCandidate(barcode: (normalized.value, observation), observations: observations, texts: texts, prices: prices)
        case .text:
            let result = queryBuilder.build(barcode: nil, recognizedText: texts)
            guard !result.query.isEmpty else { return nil }
            let identity = ProductIdentity(barcode: nil, brand: result.brand, model: result.model,
                                           titleHint: result.titleHint, rawRecognizedText: texts,
                                           query: result.query)
            let (price, ambiguous) = selectPrice(from: prices, near: observation.bounds)
            return ScanCandidate(identity: identity, storePrice: price, barcodeValue: nil,
                                 priceWasAmbiguous: ambiguous)
        case .price:
            return nil
        }
    }

    // MARK: - Internals

    private func normalizedBarcodes(from observations: [ScannerObservation]) -> [(value: String, observation: ScannerObservation)] {
        observations.compactMap { obs in
            guard case .barcode(let value, let symbology) = obs.kind,
                  let normalized = BarcodeNormalizer.normalize(value, symbology: symbology),
                  normalized.isCheckDigitValid else { return nil }
            return (normalized.value, obs)
        }
    }

    private func buildCandidate(barcode: (value: String, observation: ScannerObservation),
                                observations: [ScannerObservation],
                                texts: [String],
                                prices: [ScannerObservation]) -> ScanCandidate {
        let result = queryBuilder.build(barcode: barcode.value, recognizedText: texts)
        let query = result.query.isEmpty ? barcode.value : result.query
        let identity = ProductIdentity(barcode: barcode.value, brand: result.brand, model: result.model,
                                       titleHint: result.titleHint, rawRecognizedText: texts, query: query)
        let (price, ambiguous) = selectPrice(from: prices, near: barcode.observation.bounds)
        return ScanCandidate(identity: identity, storePrice: price, barcodeValue: barcode.value,
                             priceWasAmbiguous: ambiguous)
    }

    /// Spatially associates the best visible price with the product region.
    private func selectPrice(from prices: [ScannerObservation], near productBounds: CGRect?) -> (Money?, Bool) {
        guard !prices.isEmpty else { return (nil, false) }
        guard let productBounds else {
            // No anchor: single price wins, multiple prices are ambiguous.
            if prices.count == 1, case .price(let money) = prices[0].kind { return (money, false) }
            return (nil, true)
        }

        let neighborhood = productBounds.insetBy(dx: -160, dy: -220)
        let center = CGPoint(x: productBounds.midX, y: productBounds.midY)

        func priceCenter(_ obs: ScannerObservation) -> CGPoint {
            CGPoint(x: obs.bounds.midX, y: obs.bounds.midY)
        }

        let inside = prices.filter { neighborhood.contains(priceCenter($0)) }
        let pool = inside.isEmpty ? prices : inside
        let sorted = pool.sorted {
            priceCenter($0).distance(to: center) < priceCenter($1).distance(to: center)
        }
        guard let winner = sorted.first, case .price(let money) = winner.kind else { return (nil, false) }
        let ambiguous = sorted.count > 1
            && priceCenter(sorted[1]).distance(to: center) < priceCenter(winner).distance(to: center) * 1.3
        return (money, ambiguous)
    }
}

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        let dx = x - other.x, dy = y - other.y
        return (dx * dx + dy * dy).squareRoot()
    }
}
