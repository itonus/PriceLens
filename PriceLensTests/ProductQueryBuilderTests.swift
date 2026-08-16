import Foundation
import Testing
@testable import PriceLens

@Suite("ProductQueryBuilder")
struct ProductQueryBuilderTests {

    let builder = ProductQueryBuilder()

    @Test func sonyModelDetected() {
        let result = builder.build(barcode: nil, recognizedText: ["SONY", "WH-1000XM6", "1 799,00 zł"])
        #expect(result.brand == "Sony")
        #expect(result.model == "WH-1000XM6")
        #expect(result.query == "Sony WH-1000XM6")
    }

    @Test func barcodeOnly() {
        let result = builder.build(barcode: "5901234123457", recognizedText: [])
        #expect(result.query == "")
        #expect(result.brand == nil && result.model == nil)
    }

    @Test func brandPlusNoisyLabel() {
        let result = builder.build(barcode: nil,
                                   recognizedText: ["SUPER PROMOCJA", "Bosch", "GSR 18V-45", "Cena: 399,99 zł"])
        #expect(result.brand == "Bosch")
        #expect(result.model == "GSR 18V-45")
        #expect(result.query.contains("Bosch"))
        #expect(!result.query.lowercased().contains("promocja"))
    }

    @Test func noStrongModelFallsBackToInformativePhrase() {
        let result = builder.build(barcode: nil,
                                   recognizedText: ["PROMOCJA", "Mleko UHT 3,2%", "Cena za sztukę"])
        #expect(result.model == nil)
        #expect(!result.query.isEmpty)
        #expect(!result.query.lowercased().contains("promocja"))
        #expect(!result.query.lowercased().contains("cena"))
    }

    @Test func polishPromotionalNoiseFiltered() {
        let result = builder.build(barcode: nil, recognizedText: ["PROMOCJA", "Samsung", "SM-S938B"])
        #expect(result.query == "Samsung SM-S938B")
    }

    @Test func russianAndEnglishText() {
        let result = builder.build(barcode: nil, recognizedText: ["Наушники", "JBL", "Tune 770NC"])
        #expect(result.brand == "JBL")
    }

    @Test func priceNeverBecomesModel() {
        let result = builder.build(barcode: nil, recognizedText: ["1 799,00 zł", "79,90"])
        #expect(result.model == nil)
    }

    @Test func shortPureNumberModelAccepted() {
        let result = builder.build(barcode: nil, recognizedText: ["LEGO", "42171"])
        #expect(result.brand == "Lego")
        #expect(result.model == "42171")
        #expect(result.query == "Lego 42171")
    }
}
