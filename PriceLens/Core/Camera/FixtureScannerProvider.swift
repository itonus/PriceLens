import Foundation
import UIKit

/// Deterministic scanner for previews, DEBUG demo mode and UI tests.
/// Emits scripted recognized items so no camera is ever required in tests.
@MainActor
final class FixtureScannerProvider: ScannerProvider {
    private let scenario: FixtureScenario
    private var continuation: AsyncStream<ScannerEvent>.Continuation?
    private(set) lazy var eventStream: AsyncStream<ScannerEvent> = AsyncStream { [weak self] continuation in
        self?.continuation = continuation
    }
    var events: AsyncStream<ScannerEvent> { eventStream }

    private var emitTask: Task<Void, Never>?

    init(scenario: FixtureScenario = .successfulScan) {
        self.scenario = scenario
    }

    func start() async throws {
        emitTask?.cancel()
        emitTask = Task { [weak self] in
            guard let self else { return }
            // Emit twice so stabilization timing behaves like the real scanner.
            for _ in 0..<6 {
                try? await Task.sleep(for: .milliseconds(150))
                if Task.isCancelled { return }
                self.continuation?.yield(.observations(self.observations()))
            }
        }
    }

    func stop() {
        emitTask?.cancel()
        emitTask = nil
    }

    func capturePhoto() async throws -> UIImage { UIImage() }

    private func observations() -> [ScannerObservation] {
        let now = ContinuousClock.now
        let start = now - .milliseconds(600)
        switch scenario {
        case .successfulScan, .providerFailure, .offline:
            return [
                ScannerObservation(id: FixtureIDs.barcodeID,
                                   kind: .barcode(value: "5901234123457", symbology: "EAN13"),
                                   bounds: CGRect(x: 60, y: 320, width: 260, height: 90),
                                   firstSeen: start, lastSeen: now),
                ScannerObservation(id: FixtureIDs.textID,
                                   kind: .text(value: "SONY WH-1000XM6"),
                                   bounds: CGRect(x: 60, y: 250, width: 260, height: 40),
                                   firstSeen: start, lastSeen: now),
                ScannerObservation(id: FixtureIDs.priceID,
                                   kind: .price(Money(amount: 1799.00, currencyCode: "PLN")),
                                   bounds: CGRect(x: 60, y: 420, width: 140, height: 36),
                                   firstSeen: start, lastSeen: now)
            ]
        case .noStorePrice:
            return [
                ScannerObservation(id: FixtureIDs.barcodeID,
                                   kind: .barcode(value: "5901234123457", symbology: "EAN13"),
                                   bounds: CGRect(x: 60, y: 320, width: 260, height: 90),
                                   firstSeen: start, lastSeen: now),
                ScannerObservation(id: FixtureIDs.textID,
                                   kind: .text(value: "SONY WH-1000XM6"),
                                   bounds: CGRect(x: 60, y: 250, width: 260, height: 40),
                                   firstSeen: start, lastSeen: now)
            ]
        }
    }

    enum FixtureIDs {
        static let barcodeID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        static let textID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        static let priceID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    }
}
