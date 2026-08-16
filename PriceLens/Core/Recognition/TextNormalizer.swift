import Foundation

/// Text normalization for matching and tokenization.
enum TextNormalizer {

    /// Aggressive normalization for comparison: fold diacritics/case, strip punctuation, collapse spaces.
    static func normalizeForMatching(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        let allowed = folded.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) { return Character(scalar) }
            return " "
        }
        return String(allowed)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    static func tokens(_ text: String) -> [String] {
        normalizeForMatching(text).split(separator: " ").map(String.init)
    }

    /// Lighter cleanup for display/query: collapse whitespace, trim OCR artifacts.
    static func cleanupForDisplay(_ text: String) -> String {
        text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
