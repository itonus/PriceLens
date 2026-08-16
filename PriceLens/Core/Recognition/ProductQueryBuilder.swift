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
        let model = detectModelToken(in: lines)

        var query = ""
        var titleHint: String? = nil

        if let brand, let model {
            query = "\(brand) \(model)"
        } else if let model {
            query = model
        } else {
            let hint = informativePhrase(from: lines)
            titleHint = hint
            query = hint ?? ""
        }

        if let brand, model == nil, !query.lowercased().contains(brand.lowercased()) {
            query = "\(brand) \(query)".trimmingCharacters(in: .whitespaces)
        }

        return Result(brand: brand, model: model, titleHint: titleHint, query: query)
    }

    // MARK: - Brand detection

    func detectBrand(in lines: [String]) -> String? {
        for line in lines {
            let lineTokens = TextNormalizer.tokens(line)
            for hint in lexicon.brandHints {
                let hintTokens = TextNormalizer.tokens(hint)
                if !hintTokens.isEmpty, lineTokens.contains(hintTokens[0]) {
                    return hint
                }
            }
        }
        return nil
    }

    // MARK: - Model token detection

    /// Strong model tokens: mixed letters/digits, hyphens, uppercase, unusual length.
    /// Examples: WH-1000XM6, SM-S938B, MX2D3, 42171, GSR 18V-45.
    func detectModelToken(in lines: [String]) -> String? {
        var best: (token: String, score: Int)? = nil
        for line in lines {
            let rawTokens = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            for raw in rawTokens {
                let token = raw.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:()[]{}\"'"))
                guard let score = modelScore(token), score > 0 else { continue }
                if best == nil || score > best!.score {
                    best = (token, score)
                }
            }
            // Two-token models like "GSR 18V-45"
            for (a, b) in zip(rawTokens, rawTokens.dropFirst()) {
                let ta = a.trimmingCharacters(in: .punctuationCharacters)
                let tb = b.trimmingCharacters(in: .punctuationCharacters)
                guard ta.allSatisfy({ $0.isLetter }), ta.count <= 4, ta == ta.uppercased(),
                      let sb = modelScore(tb), sb > 0 else { continue }
                let combined = "\(ta) \(tb)"
                let score = sb + 2
                if best == nil || score > best!.score {
                    best = (combined, score)
                }
            }
        }
        return best?.token
    }

    /// Returns nil when the token is definitely not a model; score otherwise (higher = stronger).
    private func modelScore(_ token: String) -> Int? {
        guard token.count >= 4, token.count <= 18 else { return nil }
        guard token.contains(where: { $0.isNumber }) else { return nil }

        let lower = token.lowercased()
        if lexicon.stopwords.contains(lower) { return nil }
        if PriceParser.parse(token) != nil { return nil }              // prices are not models
        if token.allSatisfy({ $0.isNumber }) {
            // Pure digits: only plausible for 4-6 digit model/article numbers.
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
            let rawTokens = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            let kept = rawTokens.filter { token in
                let clean = token.trimmingCharacters(in: .punctuationCharacters)
                guard clean.count > 1 else { return false }
                let folded = TextNormalizer.normalizeForMatching(clean)
                if lexicon.stopwords.contains(folded) { return false }
                if PriceParser.parse(clean) != nil { return false }
                if clean.allSatisfy({ $0.isNumber }) { return false }
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
