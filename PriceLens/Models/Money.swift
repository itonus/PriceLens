import Foundation

/// Monetary value. Always Decimal-based; never mix currencies without conversion.
struct Money: Sendable, Hashable, Comparable {
    let amount: Decimal
    let currencyCode: String

    static func < (lhs: Money, rhs: Money) -> Bool {
        precondition(lhs.currencyCode == rhs.currencyCode, "Money comparison requires same currency")
        return lhs.amount < rhs.amount
    }

    func isCompatible(with other: Money) -> Bool {
        currencyCode.caseInsensitiveCompare(other.currencyCode) == .orderedSame
    }

    static func - (lhs: Money, rhs: Money) -> Money {
        precondition(lhs.isCompatible(with: rhs), "Money subtraction requires same currency")
        return Money(amount: lhs.amount - rhs.amount, currencyCode: lhs.currencyCode)
    }

    /// Percentage of `self` saved relative to `other` (e.g. self=1550, other=1800 -> 13.9).
    func percentSaved(relativeTo other: Money) -> Decimal? {
        guard isCompatible(with: other), other.amount > 0 else { return nil }
        return ((other.amount - amount) / other.amount * 100) as Decimal
    }
}

enum MoneyFormatter {
    static func string(_ money: Money, locale: Locale = .autoupdatingCurrent) -> String {
        money.amount.formatted(.currency(code: money.currencyCode).locale(locale))
    }

    static func string(_ amount: Decimal, currencyCode: String, locale: Locale = .autoupdatingCurrent) -> String {
        amount.formatted(.currency(code: currencyCode).locale(locale))
    }

    static func percent(_ value: Decimal, locale: Locale = .autoupdatingCurrent) -> String {
        (value / 100).formatted(.percent.precision(.fractionLength(1)).locale(locale))
    }
}
