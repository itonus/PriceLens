import Foundation

/// Computes match confidence between a scanned identity and a provider offer title/metadata.
/// Conservative by design: never claim exact without evidence.
struct OfferMatcher: Sendable {

    init() {}

    func confidence(identity: ProductIdentity,
                    offerTitle: String,
                    evidence: OfferEvidence?) -> MatchConfidence {
        let titleTokens = Set(TextNormalizer.tokens(offerTitle))

        // Exact: GTIN repeated in result metadata, or unambiguous exact model identity with brand.
        if let barcode = identity.barcode {
            if let gtin = evidence?.gtin, normalizeGTIN(gtin) == normalizeGTIN(barcode) {
                return .exact
            }
            if evidence?.mpn == nil, evidence?.gtin == nil, identity.model == nil {
                // Barcode-only search hit with no corroborating metadata: strong but not exact.
                return titleMatchLevel(identity: identity, offerTitle: offerTitle, barcodeBoost: true)
            }
        }

        if let mpn = evidence?.mpn, let model = identity.model,
           TextNormalizer.normalizeForMatching(mpn) == TextNormalizer.normalizeForMatching(model) {
            return brandCompatible(identity: identity, evidence: evidence, titleTokens: titleTokens) ? .exact : .high
        }

        return titleMatchLevel(identity: identity, offerTitle: offerTitle, barcodeBoost: false)
    }

    // MARK: - Title matching

    private func titleMatchLevel(identity: ProductIdentity,
                                 offerTitle: String,
                                 barcodeBoost: Bool) -> MatchConfidence {
        let titleTokens = Set(TextNormalizer.tokens(offerTitle))
        var score = 0
        var modelMatched = false

        if let model = identity.model {
            let modelTokens = TextNormalizer.tokens(model)
            if !modelTokens.isEmpty, modelTokens.allSatisfy({ titleTokens.contains($0) }) {
                modelMatched = true
                score += 3
            }
        }

        if let brand = identity.brand {
            let brandTokens = TextNormalizer.tokens(brand)
            if !brandTokens.isEmpty, brandTokens.allSatisfy({ titleTokens.contains($0) }) {
                score += 1
            } else if modelMatched {
                score -= 1 // model matches but brand contradicts/absent: be careful
            }
        }

        // Variant conflict check (storage, size, pack counts).
        if hasVariantConflict(identity: identity, offerTitle: offerTitle) {
            return .low
        }

        if modelMatched {
            return score >= 4 ? .high : .medium
        }

        // No model: fall back to query token overlap.
        let queryTokens = Set(TextNormalizer.tokens(identity.query))
        guard !queryTokens.isEmpty else { return .low }
        let overlap = queryTokens.intersection(titleTokens).count
        let ratio = Double(overlap) / Double(queryTokens.count)
        if barcodeBoost {
            // Result surfaced for an exact barcode query: treat decent overlap as medium.
            return ratio >= 0.5 ? .medium : .low
        }
        if ratio >= 0.9, queryTokens.count >= 2 { return .medium }
        return .low
    }

    // MARK: - Variant conflicts

    /// Detects storage/size/pack conflicts: 128 GB vs 256 GB, 0.5 L vs 1.5 L, 1-pack vs 4-pack.
    func hasVariantConflict(identity: ProductIdentity, offerTitle: String) -> Bool {
        let identityText = ([identity.query] + identity.rawRecognizedText).joined(separator: " ")
        let identityVariants = variantTokens(in: identityText)
        let offerVariants = variantTokens(in: offerTitle)

        for iv in identityVariants {
            for ov in offerVariants where ov.family == iv.family && ov.value != iv.value {
                // Only conflict when the identity carries explicit variant info.
                return true
            }
        }
        return false
    }

    struct VariantToken: Hashable {
        let family: String
        let value: String
    }

    private func variantTokens(in text: String) -> Set<VariantToken> {
        var result = Set<VariantToken>()
        let normalized = TextNormalizer.normalizeForMatching(text)
        let pattern = #"\b(\d+(?:[.,]\d+)?)\s*(gb|tb|ml|l|cl|kg|g)\b|\b(\d+)\s*(?:szt|pcs|pack)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return result }
        let range = NSRange(normalized.startIndex..., in: normalized)
        for match in regex.matches(in: normalized, range: range) {
            if let unit = Range(match.range(at: 2), in: normalized), let value = Range(match.range(at: 1), in: normalized) {
                result.insert(VariantToken(family: String(normalized[unit]).lowercased(),
                                           value: String(normalized[value])))
            } else if let value = Range(match.range(at: 3), in: normalized) {
                result.insert(VariantToken(family: "pack", value: String(normalized[value])))
            }
        }
        return result
    }

    private func brandCompatible(identity: ProductIdentity, evidence: OfferEvidence?, titleTokens: Set<String>) -> Bool {
        guard let brand = identity.brand else { return true }
        let brandTokens = Set(TextNormalizer.tokens(brand))
        if let evidenceBrand = evidence?.brand {
            return Set(TextNormalizer.tokens(evidenceBrand)) == brandTokens
        }
        return brandTokens.isSubset(of: titleTokens)
    }

    private func normalizeGTIN(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespaces).filter(\.isNumber)
    }
}
