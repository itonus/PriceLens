# Scanner and Recognition Specification

## 1. Primary scanner technology

Use `VisionKit.DataScannerViewController` for the live scanner.

Recognized data types:
- machine-readable codes,
- text,
- currency-capable text recognition where supported.

Use a SwiftUI wrapper via `UIViewControllerRepresentable`.

At runtime check:
- scanner support,
- scanner availability,
- camera authorization.

Provide a fallback state if the device cannot use DataScanner.

## 2. Barcode symbologies

Enable common retail symbologies, including:
- EAN-13
- EAN-8
- UPC-A where represented
- UPC-E
- Code 128
- Code 39
- Code 93
- QR
- Data Matrix

Do not block a useful unknown supported barcode format if VisionKit can report it safely.

## 3. OCR languages

Recognition is not the same as UI localization.

For store scanning in Poland, configure OCR for:
- Polish
- English
- Russian

Priority may follow:
1. Polish
2. selected app language
3. the remaining supported language

The app UI itself remains English/Russian only.

## 4. Recognition quality

Start with `balanced` or equivalent default behavior.

Benchmark on a real device.

If tiny shelf labels are consistently missed, test `accurate`.

Do not choose maximum accuracy by default if it makes the scanner feel delayed.

## 5. Scan event model

Represent recognized data as normalized events:

```swift
enum ScannerItemKind: Sendable {
    case barcode(value: String, symbology: String)
    case text(value: String)
    case price(Money)
}

struct ScannerObservation: Sendable, Identifiable {
    let id: UUID
    let kind: ScannerItemKind
    let bounds: CGRect
    let firstSeen: ContinuousClock.Instant
    let lastSeen: ContinuousClock.Instant
}
```

Map VisionKit item identifiers when possible.

## 6. Stabilization

Do not search on the first frame.

A candidate is lockable when:
- same barcode is observed continuously for about 350–600 ms, OR
- user taps a recognized item.

Exact value belongs in `AppConfig`.

If multiple barcodes compete:
- prefer item closest to view center only as a visual candidate,
- require user tap if ambiguity remains.

## 7. Barcode normalization

Normalize:
- trim whitespace,
- remove scanner formatting separators,
- preserve leading zeroes,
- accept digits for EAN/UPC,
- validate common check digit when applicable.

Never silently convert a questionable value into another barcode.

## 8. Price recognition

Price parser must handle at least:

```text
399,99 zł
399.99 PLN
1 799,00 zł
1 799,00 PLN
1799,-
79 zł
79,90
```

A bare numeric text is only a price candidate if:
- currency context exists nearby, OR
- it has a strong price format and location heuristic.

Do not classify model numbers as prices.

## 9. Product-price association

When barcode is selected:
1. collect visible price candidates,
2. calculate spatial distance to barcode/product region,
3. prefer candidates within a reasonable expanded neighborhood,
4. penalize very small promotional/legal text,
5. if one candidate clearly wins, auto-select,
6. if ambiguous, show price chips and let user tap.

The selected price remains editable.

## 10. OCR product query extraction

No cloud AI.

Use deterministic heuristics.

### Strong model token examples
- `WH-1000XM6`
- `SM-S938B`
- `MX2D3`
- `42171`
- `GSR 18V-45`

Signals:
- mixed letters/digits,
- hyphens,
- uppercase,
- unusual token length,
- adjacency to a brand token.

### Brand
Maintain a small optional local brand-hint list only if useful.
Do not attempt a comprehensive brand database.

### Query construction
Preferred:
`brand + exact model`

Fallback:
cleaned 3–8 high-information text tokens.

Ignore:
- `PROMOCJA`
- `SALE`
- unit-price legal text,
- store loyalty messaging,
- common packaging boilerplate.

Keep stopwords in a local resource so they can be adjusted.

## 11. High-resolution still capture

When live recognition locks but OCR data is weak, use DataScanner's high-resolution photo capture API.

Flow:
1. lock barcode,
2. call high-resolution capture,
3. run Vision text recognition on the captured image,
4. improve product query and price extraction,
5. release image from memory.

Do not save the image to Photos.
Do not persist the image in normal operation.

This is the secondary accuracy path, not the first interaction.

## 12. Overlay behavior

The overlay must map recognized item bounds correctly through orientation and view coordinate systems.

Tests/preview should cover:
- portrait device,
- safe area,
- sheet partially visible,
- rotation disabled/portrait-only if MVP chooses it.

## 13. Haptics

Use:
- subtle selection feedback for tapped recognized item,
- success feedback when scan locks,
- light impact when recommendation state becomes available if it does not feel repetitive.

Do not haptic on every OCR text update.

## 14. Torch

Show torch control only when supported.

Preserve torch state during one scanning session.
Turn it off when scanner feature leaves foreground.

## 15. Permission states

### Not determined
Explain succinctly and request permission from the scanner screen.

### Denied
Show:
- why camera is needed,
- Settings button,
- manual search entry.

### Restricted
Show manual search.

The application must remain launchable without camera permission.

## 16. Simulator support

Camera scanner cannot be the only way to test the application.

DEBUG and UI-test modes must support injected scan events such as:

```text
barcode = 5901234123457
ocr = "SONY WH-1000XM6"
storePrice = 1799.00 PLN
```

UI tests must never depend on a live camera.
