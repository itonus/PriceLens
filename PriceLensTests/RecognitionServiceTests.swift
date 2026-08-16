import Foundation
import Testing
@testable import PriceLens

@Suite("RecognitionService")
@MainActor
struct RecognitionServiceTests {

    private func obs(_ id: UUID = UUID(), kind: ScannerItemKind, bounds: CGRect, ageMs: Int) -> ScannerObservation {
        let now = ContinuousClock.now
        return ScannerObservation(id: id, kind: kind, bounds: bounds,
                                  firstSeen: now - .milliseconds(ageMs), lastSeen: now)
    }

    @Test func locksAfterStabilizationInterval() {
        let service = RecognitionService()
        let frame = [
            obs(kind: .barcode(value: "5901234123457", symbology: "EAN13"),
                bounds: CGRect(x: 60, y: 320, width: 260, height: 90), ageMs: 600),
            obs(kind: .text(value: "SONY WH-1000XM6"),
                bounds: CGRect(x: 60, y: 250, width: 260, height: 40), ageMs: 600),
            obs(kind: .price(Money(amount: 1799, currencyCode: "PLN")),
                bounds: CGRect(x: 60, y: 420, width: 140, height: 36), ageMs: 600)
        ]
        let result = service.process(frame)
        #expect(result.lock != nil)
        #expect(result.lock?.identity.barcode == "5901234123457")
        #expect(result.lock?.identity.query == "Sony WH-1000XM6")
        #expect(result.lock?.storePrice?.amount == 1799)
    }

    @Test func doesNotLockBeforeInterval() {
        let service = RecognitionService()
        let frame = [
            obs(kind: .barcode(value: "5901234123457", symbology: "EAN13"),
                bounds: .zero, ageMs: 50)
        ]
        // first call seeds firstSeen at ~now
        let result = service.process(frame)
        #expect(result.lock == nil)
        #expect(result.status == .barcodeFound)
    }

    @Test func multipleBarcodesRequireTap() {
        let service = RecognitionService()
        let frame = [
            obs(kind: .barcode(value: "5901234123457", symbology: "EAN13"),
                bounds: CGRect(x: 0, y: 0, width: 100, height: 40), ageMs: 900),
            obs(kind: .barcode(value: "012345678905", symbology: "UPCA"),
                bounds: CGRect(x: 0, y: 200, width: 100, height: 40), ageMs: 900)
        ]
        let result = service.process(frame)
        #expect(result.lock == nil)
        #expect(result.status == .tapAProduct)
        #expect(result.candidateBarcodes.count == 2)
    }

    @Test func tapSelectsProduct() {
        let service = RecognitionService()
        let barcodeID = UUID()
        let frame = [
            obs(barcodeID, kind: .barcode(value: "5901234123457", symbology: "EAN13"),
                bounds: CGRect(x: 0, y: 0, width: 100, height: 40), ageMs: 10),
            obs(kind: .barcode(value: "012345678905", symbology: "UPCA"),
                bounds: CGRect(x: 0, y: 200, width: 100, height: 40), ageMs: 10)
        ]
        _ = service.process(frame)
        let candidate = service.lock(observation: frame[0], in: frame)
        #expect(candidate?.identity.barcode == "5901234123457")
    }

    @Test func textOnlyStrongModelLocks() {
        let service = RecognitionService()
        let frame = [
            obs(kind: .text(value: "SONY WH-1000XM6"),
                bounds: CGRect(x: 0, y: 0, width: 200, height: 30), ageMs: 2000)
        ]
        let result = service.process(frame)
        #expect(result.lock?.identity.model == "WH-1000XM6")
    }

    @Test func invalidCheckDigitBarcodeNotLockable() {
        let service = RecognitionService()
        let frame = [
            obs(kind: .barcode(value: "5901234123458", symbology: "EAN13"),
                bounds: .zero, ageMs: 900)
        ]
        let result = service.process(frame)
        #expect(result.lock == nil)
    }
}
