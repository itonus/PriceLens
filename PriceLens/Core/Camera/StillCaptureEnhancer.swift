import Foundation
import Vision
import UIKit

/// Secondary accuracy path: after a barcode lock with weak OCR, a high-resolution
/// still is captured and Vision text recognition improves query/price extraction.
/// The image is used in memory and immediately released — never saved to Photos.
enum StillCaptureEnhancer {

    struct Enhancement: Sendable {
        var texts: [String]
        var prices: [Money]
    }

    static func analyze(_ image: UIImage, languages: [String] = AppConfig.default.ocrLanguages) async -> Enhancement {
        guard let cgImage = image.cgImage else { return Enhancement(texts: [], prices: []) }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                var texts: [String] = []
                var prices: [Money] = []
                for observation in observations {
                    guard let candidate = observation.topCandidates(1).first else { continue }
                    let string = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !string.isEmpty else { continue }
                    if let price = PriceParser.parse(string) {
                        prices.append(price)
                    } else {
                        texts.append(string)
                    }
                }
                continuation.resume(returning: Enhancement(texts: texts, prices: prices))
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = languages
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                Log.recognition.error("Still capture OCR failed: \(error.localizedDescription)")
                continuation.resume(returning: Enhancement(texts: [], prices: []))
            }
        }
    }
}
