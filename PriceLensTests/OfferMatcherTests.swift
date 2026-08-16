import Foundation
import Testing
@testable import PriceLens

@Suite("OfferMatcher")
struct OfferMatcherTests {

    let matcher = OfferMatcher()

    func identity(barcode: String? = nil, brand: String? = nil, model: String? = nil, query: String = "") -> ProductIdentity {
        ProductIdentity(barcode: barcode, brand: brand, model: model,
                        titleHint: nil, rawRecognizedText: [], query: query)
    }

    @Test func exactViaGTIN() {
        let id = identity(barcode: "5901234123457")
        let evidence = OfferEvidence(gtin: "5901234123457", extractionStrategy: "json-ld")
        #expect(matcher.confidence(identity: id, offerTitle: "Sony WH-1000XM6", evidence: evidence) == .exact)
    }

    @Test func exactViaMPNWithBrand() {
        let id = identity(brand: "Sony", model: "WH-1000XM6", query: "Sony WH-1000XM6")
        let evidence = OfferEvidence(mpn: "WH-1000XM6", brand: "Sony", extractionStrategy: "json-ld")
        #expect(matcher.confidence(identity: id, offerTitle: "WH-1000XM6", evidence: evidence) == .exact)
    }

    @Test func highViaBrandAndModelInTitle() {
        let id = identity(brand: "Sony", model: "WH-1000XM6", query: "Sony WH-1000XM6")
        #expect(matcher.confidence(identity: id,
                                   offerTitle: "Słuchawki Sony WH-1000XM6 czarne",
                                   evidence: nil) == .high)
    }

    @Test func differentStorageVariantIsLow() {
        let id = identity(brand: "Apple", model: "MX2D3", query: "Apple MX2D3 256 GB")
        // Identity mentions 256 GB, title says 128 GB -> conflict
        let result = matcher.confidence(identity: id, offerTitle: "Apple iPhone MX2D3 128 GB", evidence: nil)
        #expect(result == .low)
    }

    @Test func differentPackQuantityIsLow() {
        let id = identity(query: "Detergent 4 szt")
        let result = matcher.confidence(identity: id, offerTitle: "Detergent 1 szt", evidence: nil)
        #expect(result == .low)
    }

    @Test func sameBrandDifferentModelNotExact() {
        let id = identity(brand: "Sony", model: "WH-1000XM6", query: "Sony WH-1000XM6")
        let result = matcher.confidence(identity: id, offerTitle: "Sony WH-1000XM5", evidence: nil)
        #expect(result != .exact && result != .high)
    }

    @Test func genericTitleOnlyIsLow() {
        let id = identity(query: "mleko")
        let result = matcher.confidence(identity: id, offerTitle: "Produkt spożywczy promocja", evidence: nil)
        #expect(result == .low)
    }

    @Test func barcodeQueryHitWithoutMetadataNotExact() {
        let id = identity(barcode: "5901234123457")
        let result = matcher.confidence(identity: id, offerTitle: "Sony WH-1000XM6", evidence: nil)
        #expect(result != .exact)
    }
}
