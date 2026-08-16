import Foundation

struct NormalizedBarcode: Sendable, Hashable {
    let value: String
    let symbology: String
    let isCheckDigitValid: Bool
}

/// Normalizes raw barcode payloads. Never converts a questionable value into another barcode.
enum BarcodeNormalizer {

    /// Symbology names match VNBarcodeSymbology raw values (e.g. "EAN13", "Code128", "QR").
    static func normalize(_ raw: String, symbology: String) -> NormalizedBarcode? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
        guard !trimmed.isEmpty else { return nil }

        let sym = symbology.lowercased()
        switch sym {
        case "ean13", "ean-13":
            return eanLike(trimmed, symbology: "EAN-13", length: 13)
        case "ean8", "ean-8":
            return eanLike(trimmed, symbology: "EAN-8", length: 8)
        case "upca", "upc-a":
            return eanLike(trimmed, symbology: "UPC-A", length: 12)
        case "upce", "upc-e":
            // UPC-E has its own check scheme; validate digits + length only.
            guard trimmed.count == 8, trimmed.allSatisfy(\.isNumber) else { return nil }
            return NormalizedBarcode(value: trimmed, symbology: "UPC-E", isCheckDigitValid: true)
        case "code39", "code93", "code128", "code39mod43", "codabar", "i2of5", "itf14":
            // Alphanumeric symbologies: keep payload as scanned.
            let allowed = trimmed.range(of: #"^[A-Za-z0-9 .$/+%:-]+$"#, options: .regularExpression) != nil
            guard allowed else { return nil }
            return NormalizedBarcode(value: trimmed, symbology: symbology.uppercased(), isCheckDigitValid: true)
        case "qr", "qrcode":
            return NormalizedBarcode(value: raw.trimmingCharacters(in: .whitespacesAndNewlines),
                                     symbology: "QR", isCheckDigitValid: true)
        case "datamatrix", "aztec", "pdf417", "microqr", "micropdf417":
            return NormalizedBarcode(value: trimmed, symbology: symbology.uppercased(), isCheckDigitValid: true)
        default:
            // Do not block a useful unknown supported format.
            return NormalizedBarcode(value: trimmed, symbology: symbology, isCheckDigitValid: true)
        }
    }

    private static func eanLike(_ value: String, symbology: String, length: Int) -> NormalizedBarcode? {
        guard value.count == length, value.allSatisfy(\.isNumber) else { return nil }
        return NormalizedBarcode(value: value, symbology: symbology,
                                 isCheckDigitValid: isValidGTINCheckDigit(value))
    }

    /// GTIN (EAN-13/EAN-8/UPC-A) mod-10 check digit.
    static func isValidGTINCheckDigit(_ value: String) -> Bool {
        let digits = value.compactMap { $0.wholeNumberValue }
        guard digits.count == value.count, digits.count >= 2 else { return false }
        let check = digits.last!
        let body = digits.dropLast()
        var sum = 0
        // From the rightmost body digit, weights alternate 3,1,3,1...
        for (index, digit) in body.reversed().enumerated() {
            sum += digit * (index % 2 == 0 ? 3 : 1)
        }
        return (10 - (sum % 10)) % 10 == check
    }
}
