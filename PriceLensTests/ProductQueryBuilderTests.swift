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

    /// Regression: the printed human-readable digits under a barcode (OCR'd as plain text)
    /// must never be picked up as a fake "model number" that hijacks the query/title.
    @Test func barcodeDigitFragmentNotTreatedAsModel() {
        let result = builder.build(barcode: "5996379357362", recognizedText: ["599637", "935736 2"])
        #expect(result.model == nil)
        #expect(result.query != "599637")
    }

    /// Regression: "L'Oreal" folds to tokens ["l","oreal"]; matching only the first token meant
    /// any line containing a stray lone "l" (common OCR noise) falsely detected as L'Oreal.
    @Test func strayLetterDoesNotFalselyMatchApostropheBrand() {
        let result = builder.build(barcode: nil, recognizedText: ["01.2027", "KE 25F"])
        #expect(result.brand == nil)
    }

    /// Regression: manufacture/expiry dates and lot codes ("01.2027") are not product info
    /// and must not leak into the query as if they were part of the title.
    @Test func dateLikeTokenExcludedFromQuery() {
        let result = builder.build(barcode: nil, recognizedText: ["01.2027", "Snack Chips"])
        #expect(!result.query.contains("01.2027"))
    }

    /// Regression: any weak pure-digit OCR fragment (not just barcode substrings — misreads,
    /// weights, lot numbers) must never become the model/query once a barcode already anchors
    /// identity. The barcode itself is a stronger, more honest fallback than a guessed number.
    @Test func weakDigitFragmentNeverOverridesBarcodeIdentity() {
        let result = builder.build(barcode: "4014400907278", recognizedText: ["1414", "KE 25F"])
        #expect(result.model == nil)
        #expect(result.query != "1414")
    }

    /// Regression: shipping-label lines ("LOT NO/DATE:2316X", "MODEL NO:1882", "WO 23477096",
    /// "TEAM: PSUZ") must not be mistaken for the product name/model — their alphanumeric codes
    /// otherwise look exactly like a plausible model number. The real descriptive line
    /// ("XBOX SERIES X 1TB...") should be used instead.
    /// Regression: multilingual packaging contains ordinary words that collide with short
    /// acronym brands — Estonian "kõlblikkuse aeg piiramata" (shelf life unlimited) was
    /// matching the appliance brand AEG. Short hints must match the exact uppercase form.
    @Test func lowercaseWordDoesNotMatchShortAcronymBrand() {
        let result = builder.build(barcode: "8004260487900",
                                   recognizedText: ["kõlblikkuse aeg piiramata",
                                                    "termin ważności nieograniczony"])
        #expect(result.brand == nil)
        #expect(result.query != "AEG")
    }

    @Test func uppercaseAcronymBrandStillDetected() {
        let result = builder.build(barcode: nil, recognizedText: ["AEG", "L6FBG49SK"])
        #expect(result.brand == "AEG")
    }

    @Test func shippingLabelLinesExcludedFromIdentity() {
        let result = builder.build(barcode: "889842640724", recognizedText: [
            "TEAM: PSUZ", "LOT NO/DATE:2316X", "WO 23477096", "MODEL NO:1882",
            "XBOX SERIES X 1TB EN/FR/ES US/CA SX", "Made in China"
        ])
        #expect(result.brand == "Xbox")
        #expect(result.model != "2316X")
        #expect(!result.query.contains("2316X"))
        #expect(!result.query.contains("23477096"))
        #expect(!result.query.contains("1882"))
    }

    /// Regression: manufacturer address lines ("g.29 Kaunas, Lietuva", "ul. Mleczarska 31,
    /// 06-400 Ciechanów") are not product identity — house numbers like "g.29" otherwise score
    /// as plausible model tokens.
    @Test func addressLinesExcludedFromIdentity() {
        let result = builder.build(barcode: "8004260487900", recognizedText: [
            "g.29 Kaunas, Lietuva",
            "ul. Mleczarska 31, 06-400 Ciechanów, Polska",
            "Bullu iela 74, Riga, LV - 1067, Latvija",
        ])
        #expect(result.model == nil)
        #expect(!result.query.contains("g.29"))
        #expect(!result.query.contains("29"))
    }
}
