import Foundation
import Testing
@testable import PriceLens

@Suite("PriceParser")
struct PriceParserTests {

    @Test func commaDecimalWithZloty() {
        let money = PriceParser.parse("399,99 zł")
        #expect(money == Money(amount: Decimal(string: "399.99")!, currencyCode: "PLN"))
    }

    @Test func dotDecimalWithPLN() {
        let money = PriceParser.parse("399.99 PLN")
        #expect(money == Money(amount: Decimal(string: "399.99")!, currencyCode: "PLN"))
    }

    @Test func spaceThousandsCommaDecimal() {
        let money = PriceParser.parse("1 799,00 zł")
        #expect(money == Money(amount: Decimal(string: "1799.00")!, currencyCode: "PLN"))
    }

    @Test func nonBreakingSpaceThousands() {
        let money = PriceParser.parse("1\u{00A0}799,00 PLN")
        #expect(money == Money(amount: Decimal(string: "1799.00")!, currencyCode: "PLN"))
        let narrow = PriceParser.parse("1\u{202F}799,00 zł")
        #expect(narrow == Money(amount: Decimal(string: "1799.00")!, currencyCode: "PLN"))
    }

    @Test func dashDecimals() {
        let money = PriceParser.parse("1799,-")
        #expect(money == Money(amount: Decimal(string: "1799")!, currencyCode: "PLN"))
    }

    @Test func integerWithCurrency() {
        let money = PriceParser.parse("79 zł")
        #expect(money == Money(amount: 79, currencyCode: "PLN"))
    }

    @Test func bareCommaDecimalIsStrongFormat() {
        let money = PriceParser.parse("79,90")
        #expect(money == Money(amount: Decimal(string: "79.90")!, currencyCode: "PLN"))
    }

    @Test func bareIntegerIsNotAPrice() {
        #expect(PriceParser.parse("42171") == nil)
        #expect(PriceParser.parse("128") == nil)
    }

    @Test func freeDeliveryText() {
        // "darmowa dostawa" contains no number -> no price
        #expect(PriceParser.parse("darmowa dostawa") == nil)
    }

    @Test func malformedPriceRejected() {
        #expect(PriceParser.parse("zł") == nil)
        #expect(PriceParser.parse("") == nil)
        #expect(PriceParser.parse(",,") == nil)
    }

    @Test func installmentRejected() {
        #expect(PriceParser.parse("10 x 39,90 zł") == nil)
        #expect(PriceParser.parse("39,90 zł /mies.") == nil)
        #expect(PriceParser.parse("rata 39,90 zł") == nil)
    }

    @Test func percentAndSavingsRejected() {
        #expect(PriceParser.parse("-20% 399,99 zł") == nil)
        #expect(PriceParser.parse("oszczędzasz 50 zł") == nil)
    }

    @Test func perUnitRejected() {
        #expect(PriceParser.parse("19,99 zł/kg") == nil)
        #expect(PriceParser.parse("5,00 zł / szt.") == nil)
    }

    @Test func parseFirstFindsPriceInLongerText() {
        let money = PriceParser.parseFirst(in: "Sony WH-1000XM6 1 549,00 zł darmowa dostawa")
        #expect(money == Money(amount: Decimal(string: "1549.00")!, currencyCode: "PLN"))
    }

    @Test func moneyComparisonAndSubtraction() {
        let a = Money(amount: 1799, currencyCode: "PLN")
        let b = Money(amount: 1549, currencyCode: "PLN")
        #expect(a > b)
        #expect((a - b).amount == 250)
        #expect(b.percentSaved(relativeTo: a)!.description.hasPrefix("13.89"))
    }
}
