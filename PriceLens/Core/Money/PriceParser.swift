import Foundation

/// Parses monetary values from OCR text and provider HTML.
/// Handles Polish formats: `399,99 zł`, `399.99 PLN`, `1 799,00 zł`, NBSP thousands, `1799,-`, `79 zł`, `79,90`.
/// Rejects installments, per-unit prices, percentages and savings text.
enum PriceParser {

    private static let currencyTokens = ["zł", "zlt", "pln", "zŁ", "PLN", "ZŁ", "Pln"]

    /// Normalizes exotic whitespace so grouping works uniformly.
    static func normalizeSpaces(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{00A0}", with: " ")   // NBSP
            .replacingOccurrences(of: "\u{202F}", with: " ")   // narrow NBSP
            .replacingOccurrences(of: "\u{2009}", with: " ")   // thin space
    }

    /// Strict single-value parse: the whole (trimmed) text should be one price, optionally with currency.
    static func parse(_ rawText: String, defaultCurrency: String = "PLN") -> Money? {
        let text = normalizeSpaces(rawText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !containsRejectedContext(text) else { return nil }

        // Currency context?
        let lower = text.lowercased()
        let hasCurrency = currencyTokens.contains { lower.contains($0.lowercased()) }

        // Find the numeric core.
        guard let match = numberMatch(in: text) else { return nil }

        // A bare integer without currency context is not a price (could be a model number).
        if match.isBareInteger && !hasCurrency { return nil }

        guard let amount = decimal(from: match) else { return nil }
        guard amount > 0, amount < 10_000_000 else { return nil }

        return Money(amount: amount, currencyCode: hasCurrency ? "PLN" : defaultCurrency)
    }

    /// Finds the first plausible price inside a longer text (used on OCR lines / provider snippets).
    static func parseFirst(in rawText: String, defaultCurrency: String = "PLN") -> Money? {
        let text = normalizeSpaces(rawText)
        guard !containsRejectedContext(text) else { return nil }
        let lower = text.lowercased()
        let hasCurrency = currencyTokens.contains { lower.contains($0.lowercased()) }

        for case let match in numberMatches(in: text) {
            if match.isBareInteger && !hasCurrency { continue }
            if let amount = decimal(from: match), amount > 0, amount < 10_000_000 {
                return Money(amount: amount, currencyCode: hasCurrency ? "PLN" : defaultCurrency)
            }
        }
        return nil
    }

    // MARK: - Rejection context

    static func containsRejectedContext(_ text: String) -> Bool {
        let lower = text.lowercased()
        if lower.contains("%") { return true }                       // percent / savings
        if lower.range(of: #"\d+\s*[x×]\s*\d"#, options: .regularExpression) != nil { return true } // installments "10 x 23,50"
        if lower.range(of: #"/\s*(mies|msc|mc|kg|g\b|l\b|ml|szt|opak|100)"#, options: .regularExpression) != nil { return true } // per-unit
        let words = ["rat", "rata", "miesiąc", "miesiecznie", "oszczęd", "save", "saving", "taniej o"]
        return words.contains { lower.contains($0) }
    }

    // MARK: - Number extraction

    struct NumberMatch {
        let digits: String      // integer part without separators
        let fraction: String?   // fractional digits
        let isBareInteger: Bool
    }

    /// Number with optional space/dot thousands and comma/dot decimals:
    /// `1 799,00` `1.799,00` `1,799.00` `1799,-` `79,90` `399.99`
    private static let numberRegex = try! NSRegularExpression(
        pattern: #"(?<![\d.,])((?:\d{1,3}(?:[ .]\d{3})+|\d+)([,.]\d{1,2}|[,.]-)?)(?![\d.,])"#
    )

    static func numberMatches(in text: String) -> [NumberMatch] {
        let range = NSRange(text.startIndex..., in: text)
        return numberRegex.matches(in: text, range: range).compactMap { m -> NumberMatch? in
            guard let core = Range(m.range(at: 1), in: text) else { return nil }
            let coreStr = String(text[core])
            let fractionGroup = m.range(at: 2)
            var fraction: String? = nil
            if let fr = Range(fractionGroup, in: text) {
                fraction = String(text[fr])
            }
            return buildMatch(core: coreStr, fraction: fraction)
        }
    }

    static func numberMatch(in text: String) -> NumberMatch? {
        let matches = numberMatches(in: text)
        // Strict parse: only one numeric token allowed in the string.
        guard matches.count == 1 else { return nil }
        return matches.first
    }

    private static func buildMatch(core: String, fraction: String?) -> NumberMatch? {
        var integerPart = core
        var frac = fraction

        // Split off trailing decimal separator group from the core when regex merged it.
        if let fr = frac, core.hasSuffix(fr) {
            integerPart = String(core.dropLast(fr.count))
        }

        // "1799,-" is a strong price format (explicit empty decimals).
        var hadDashFraction = false
        if let f = frac, f.hasSuffix("-") {
            hadDashFraction = true
            frac = nil
        }

        // Normalize fraction: strip the leading separator, keep digits only.
        if let f = frac {
            let digits = String(f.dropFirst())
            frac = digits.isEmpty ? nil : digits
        }

        // Disambiguate separators in integer part: if it contains both space-thousands
        // and a dot/comma decimal, the decimal part was already captured in `fraction`.
        var digits = integerPart
        if frac != nil {
            // thousands separators inside integer part
            if integerPart.contains(" ") {
                digits = integerPart.replacingOccurrences(of: " ", with: "")
            } else if integerPart.contains("."), integerPart.contains(",") {
                digits = integerPart.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: "")
            } else if integerPart.contains(".") {
                // "1.799" style thousands
                digits = integerPart.replacingOccurrences(of: ".", with: "")
            } else if integerPart.contains(",") {
                digits = integerPart.replacingOccurrences(of: ",", with: "")
            }
        } else {
            // No fraction captured: separators may be thousands or decimal.
            if integerPart.contains(" ") {
                digits = integerPart.replacingOccurrences(of: " ", with: "")
            } else if integerPart.range(of: #"^\d{1,3}([.,]\d{3})+$"#, options: .regularExpression) != nil {
                digits = integerPart.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: "")
            } else if integerPart.contains(".") || integerPart.contains(",") {
                // single separator with 1-2 trailing digits would have been captured as fraction;
                // a lone separator here with 3+ trailing digits is thousands.
                digits = integerPart.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: "")
            }
        }

        guard !digits.isEmpty, digits.allSatisfy(\.isNumber) else { return nil }

        let hasDecimal = frac != nil || hadDashFraction
            || integerPart.contains(where: { $0 == "." || $0 == "," }) || core.contains(" ")
        let isBareInteger = !hasDecimal
        return NumberMatch(digits: digits, fraction: frac, isBareInteger: isBareInteger)
    }

    static func decimal(from match: NumberMatch) -> Decimal? {
        var string = match.digits
        if let fraction = match.fraction {
            string += "." + fraction
        }
        return Decimal(string: string)
    }
}
