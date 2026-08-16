import Foundation

/// Local lexicon resource for OCR query building. Loaded from ProviderExtractionRules.json.
struct RecognitionLexicon: Sendable {
    let stopwords: Set<String>
    let brandHints: [String]

    static let shared = RecognitionLexicon.load()

    private struct Raw: Decodable {
        let stopwords: [String]
        let brandHints: [String]
    }

    private static func load() -> RecognitionLexicon {
        guard let url = Bundle.main.url(forResource: "ProviderExtractionRules", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode(Raw.self, from: data) else {
            Log.recognition.warning("ProviderExtractionRules.json missing; using empty lexicon")
            return RecognitionLexicon(stopwords: [], brandHints: [])
        }
        return RecognitionLexicon(stopwords: Set(raw.stopwords.map { $0.lowercased() }),
                                  brandHints: raw.brandHints)
    }
}
