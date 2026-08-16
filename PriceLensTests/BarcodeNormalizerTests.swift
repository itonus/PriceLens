import Foundation
import Testing
@testable import PriceLens

@Suite("BarcodeNormalizer")
struct BarcodeNormalizerTests {

    @Test func validEAN13() {
        // 5901234123457 has valid GTIN check digit
        let result = BarcodeNormalizer.normalize("5901234123457", symbology: "EAN13")
        #expect(result?.value == "5901234123457")
        #expect(result?.isCheckDigitValid == true)
    }

    @Test func whitespaceAndSeparatorsTrimmed() {
        let result = BarcodeNormalizer.normalize("  5901234 123457 ", symbology: "EAN13")
        #expect(result?.value == "5901234123457")
    }

    @Test func leadingZeroPreserved() {
        let result = BarcodeNormalizer.normalize("012345678905", symbology: "UPCA")
        #expect(result?.value == "012345678905")
    }

    @Test func invalidCheckDigitFlaggedNotConverted() {
        let result = BarcodeNormalizer.normalize("5901234123458", symbology: "EAN13")
        #expect(result != nil)
        #expect(result?.isCheckDigitValid == false)
    }

    @Test func wrongLengthRejected() {
        #expect(BarcodeNormalizer.normalize("59012341234", symbology: "EAN13") == nil)
    }

    @Test func nonDigitsRejectedForEAN() {
        #expect(BarcodeNormalizer.normalize("590123412345A", symbology: "EAN13") == nil)
    }

    @Test func validEAN8() {
        // 96385074 has valid check digit
        let result = BarcodeNormalizer.normalize("96385074", symbology: "EAN8")
        #expect(result?.isCheckDigitValid == true)
    }

    @Test func code128AllowsAlphanumerics() {
        let result = BarcodeNormalizer.normalize("ABC-123-xyz", symbology: "Code128")
        #expect(result?.value == "ABC123xyz")
    }

    @Test func checkDigitAlgorithm() {
        #expect(BarcodeNormalizer.isValidGTINCheckDigit("5901234123457"))
        #expect(BarcodeNormalizer.isValidGTINCheckDigit("012345678905")) // UPC-A
        #expect(!BarcodeNormalizer.isValidGTINCheckDigit("012345678904"))
    }
}
