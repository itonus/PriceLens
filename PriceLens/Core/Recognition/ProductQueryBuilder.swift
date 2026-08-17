import Foundation

/// Builds a ProductIdentity from recognized OCR text (and optional barcode).
/// Deterministic heuristics only — no cloud AI.
struct ProductQueryBuilder: Sendable {

    let lexicon: RecognitionLexicon

    init(lexicon: RecognitionLexicon = .shared) {
        self.lexicon = lexicon
    }

    struct Result: Sendable, Hashable {
        var brand: String?
        var model: String?
        var titleHint: String?
        var query: String
    }

    func build(barcode: String?, recognizedText: [String]) -> Result {
        let lines = recognizedText
            .map(TextNormalizer.cleanupForDisplay)
            .filter { !$0.isEmpty }

        let brand = detectBrand(in: lines)
        let model = detectModelToken(in: lines, barcode: barcode)

        var query = ""
        var titleHint: String? = nil

        if let brand, let model {
            query = "\(brand) \(model)"
        } else if let model {
            query = model
        } else if let brand {
            query = brand
        } else {
            // Falls back to a descriptive OCR phrase (e.g. "XBOX SERIES X 1TB"). Shipping/label
            // lines (lot/date/work-order/serial codes) are excluded by `isNoiseLabelLine`, so
            // this is safe to use even when a barcode is already present — it only enriches the
            // display title/secondary query candidate; the barcode itself always stays the
            // primary search key (see ProductIdentity.queryCandidates).
            let hint = informativePhrase(from: lines)
            titleHint = hint
            query = hint ?? ""
        }

        return Result(brand: brand, model: model, titleHint: titleHint, query: query)
    }

    // MARK: - Brand detection

    func detectBrand(in lines: [String]) -> String? {
        for line in lines {
            guard !isNoiseLabelLine(line) else { continue }
            let lineTokens = Set(TextNormalizer.tokens(line))
            // Raw (unfolded) tokens, so short acronym brands can be checked case-sensitively.
            let rawTokens = Set(line.split(whereSeparator: { $0.isWhitespace })
                .map { $0.trimmingCharacters(in: .punctuationCharacters) })

            for hint in lexicon.brandHints {
                let hintTokens = TextNormalizer.tokens(hint)
                guard !hintTokens.isEmpty else { continue }
                // Require every token of the hint to appear, not just the first: brands like
                // "L'Oreal" or "Oral-B" fold to ["l","oreal"]/["oral","b"], and matching only
                // the first token means a single stray "l" from OCR noise falsely matches.
                guard hintTokens.allSatisfy({ lineTokens.contains($0) }) else { continue }

                // Short acronym brands (AEG, LG, HP) collide with ordinary words in other
                // languages — Estonian "aeg" (time) on multilingual packaging matched AEG.
                // Case-folded matching is too weak for these: demand the exact uppercase form.
                if hint.count <= 3 {
                    guard rawTokens.contains(hint.uppercased()) else { continue }
                }
                return hint
            }
        }
        return nil
    }

    // MARK: - Model token detection

    /// Strong model tokens: mixed letters/digits, hyphens, uppercase, unusual length.
    /// Examples: WH-1000XM6, SM-S938B, MX2D3, 42171, GSR 18V-45.
    func detectModelToken(in lines: [String], barcode: String? = nil) -> String? {
        var best: (token: String, score: Int)? = nil
        for line in lines {
            guard !isNoiseLabelLine(line) else { continue }
            let rawTokens = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            for raw in rawTokens {
                let token = raw.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:()[]{}\"'"))
                guard let score = modelScore(token, barcode: barcode), score > 0 else { continue }
                if best == nil || score > best!.score {
                    best = (token, score)
                }
            }
            // Two-token models like "GSR 18V-45" (skip when the first token is a known brand).
            for (a, b) in zip(rawTokens, rawTokens.dropFirst()) {
                let ta = a.trimmingCharacters(in: .punctuationCharacters)
                let tb = b.trimmingCharacters(in: .punctuationCharacters)
                guard ta.allSatisfy({ $0.isLetter }), (2...4).contains(ta.count), ta == ta.uppercased(),
                      !isBrandToken(ta),
                      let sb = modelScore(tb, barcode: barcode), sb > 0 else { continue }
                let combined = "\(ta) \(tb)"
                let score = sb + 2
                if best == nil || score > best!.score {
                    best = (combined, score)
                }
            }
        }
        return best?.token
    }

    /// Shipping/compliance label lines ("LOT NO/DATE: 2316X", "MODEL NO:1882", "WO 23477096",
    /// "TEAM: PSUZ", "SN 053408231617", "MADE IN CHINA") carry logistics metadata, not product
    /// identity — their alphanumeric codes otherwise look exactly like a plausible model number
    /// to `modelScore`. Skip the whole line rather than try to filter individual tokens.
    private static let noiseLineStarters: Set<String> = [
        "lot", "date", "wo", "team", "sn", "serial", "sku", "batch", "mfg",
        "made", "distribution", "ref", "qty", "exp", "part", "pn", "model"
    ]

    /// Address/contact markers, incl. street abbreviations across the languages that appear on
    /// EU packaging: ul./g./vul./iela/str./tel./fax/email. A line like
    /// "г.29 Kaunas, Lietuva" or "ul. Mleczarska 31, 06-400 Ciechanów" is a manufacturer address,
    /// and its house numbers ("g.29") otherwise score as plausible model tokens.
    private static let addressMarkers: Set<String> = [
        "ul", "al", "os", "pl", "g", "gatve", "vul", "iela", "str", "korp", "kom",
        "tel", "fax", "faks", "mail", "email", "www", "biuro", "sp", "zoo", "ooo", "sooo"
    ]

    private func isNoiseLabelLine(_ line: String) -> Bool {
        let tokens = TextNormalizer.tokens(line)
        guard let first = tokens.first else { return false }
        if Self.noiseLineStarters.contains(first) { return true }
        // Address markers can appear anywhere in the line, not only at the start.
        if tokens.contains(where: { Self.addressMarkers.contains($0) }) { return true }
        // Postal codes ("06-400") are a strong address signal on their own.
        if line.range(of: #"\b\d{2}-\d{3}\b"#, options: .regularExpression) != nil { return true }
        return false
    }

    private func isBrandToken(_ token: String) -> Bool {
        let folded = TextNormalizer.normalizeForMatching(token)
        return lexicon.brandHints.contains { TextNormalizer.normalizeForMatching($0) == folded }
    }

    /// Returns nil when the token is definitely not a model; score otherwise (higher = stronger).
    private func modelScore(_ token: String, barcode: String? = nil) -> Int? {
        // Real consumer model numbers are short (WH-1000XM6 = 10, SM-S938B = 8). Longer mixed
        // alphanumeric runs are serial/lot codes printed under the barcode ("JFA25-07/23L043447")
        // — they score high on every "looks like a model" signal, so bound the length instead.
        guard token.count >= 4, token.count <= 12 else { return nil }
        // Slashes appear in serials and locale lists ("EN/FR/ES"), never in model numbers.
        guard !token.contains("/") else { return nil }
        guard token.contains(where: { $0.isNumber }) else { return nil }

        let lower = token.lowercased()
        if lexicon.stopwords.contains(lower) { return nil }
        if PriceParser.parse(token) != nil { return nil }              // prices are not models
        if token.allSatisfy({ $0.isNumber }) {
            // Pure digits are a weak signal (article/lot/date numbers all look like this) and
            // only plausible as a model when nothing more reliable exists. When a barcode was
            // already recognized, it is a far stronger identity than any bare digit string OCR
            // might pick up from the packaging (barcode's own printed digits, dates, lot codes,
            // weights) — never let one override or masquerade as the model/query in that case.
            guard barcode == nil else { return nil }
            guard (4...6).contains(token.count) else { return nil }
            return 1
        }
        guard token.contains(where: { $0.isLetter }) else { return nil }

        var score = 2
        if token.contains("-") { score += 2 }
        let letters = token.filter { $0.isLetter }
        if !letters.isEmpty, letters == letters.uppercased() { score += 2 }
        if token.range(of: #"[A-Za-z]+\d+|\d+[A-Za-z]+"#, options: .regularExpression) != nil { score += 1 }
        return score
    }

    // MARK: - Informative phrase fallback

    /// 3-8 high-information tokens with promotional noise removed.
    func informativePhrase(from lines: [String]) -> String? {
        var candidates: [String] = []
        for line in lines {
            guard !isNoiseLabelLine(line) else { continue }
            let rawTokens = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            let kept = rawTokens.filter { token in
                let clean = token.trimmingCharacters(in: .punctuationCharacters)
                guard clean.count > 1 else { return false }
                let folded = TextNormalizer.normalizeForMatching(clean)
                if lexicon.stopwords.contains(folded) { return false }
                if PriceParser.parse(clean) != nil { return false }
                // Dates/lot codes ("01.2027", "25-12-26") and pure numbers carry no product
                // information: reject any token that has digits but no letters at all.
                if clean.contains(where: { $0.isNumber }), !clean.contains(where: { $0.isLetter }) {
                    return false
                }
                return true
            }
            guard !kept.isEmpty else { continue }
            let phrase = kept.prefix(8).joined(separator: " ")
            if !phrase.isEmpty { candidates.append(phrase) }
        }
        // Prefer the longest informative line (most context).
        return candidates.max(by: { $0.count < $1.count })
    }
}
