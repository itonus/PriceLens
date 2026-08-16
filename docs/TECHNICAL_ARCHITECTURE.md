# Technical Architecture

## 1. Architecture summary

PriceLens is a fully standalone iOS application.

```text
┌──────────────────────────────────────┐
│                iPhone                │
│                                      │
│  VisionKit / Vision                  │
│      │                               │
│      ▼                               │
│  Recognition Coordinator            │
│      │                               │
│      ▼                               │
│  Product Query Builder               │
│      │                               │
│      ▼                               │
│  Search Coordinator                  │
│   ┌──────────────┬───────────────┐   │
│   │ Google Web   │ Allegro Web   │   │
│   │ Adapter      │ Adapter       │   │
│   └───────┬──────┴───────┬───────┘   │
│           ▼              ▼           │
│      Normalization / Matching        │
│              │                       │
│              ▼                       │
│         Decision Engine              │
│              │                       │
│              ▼                       │
│            SwiftUI                   │
│                                      │
│  SwiftData: history/cache metadata   │
└──────────────────────────────────────┘
```

There is no server boundary.

## 2. Platform

- Swift
- SwiftUI
- iPhone
- minimum iOS 18
- conditional iOS 26+ visual features
- portrait-first
- Swift concurrency

## 3. Dependencies

### Apple frameworks
- SwiftUI
- Foundation
- VisionKit
- Vision
- SwiftData
- SafariServices
- WebKit where required for provider fallback/extraction
- OSLog
- AVFoundation only for fallback/supporting camera capabilities
- Testing
- XCTest for UI automation

### Swift Package Manager
- SwiftSoup
- Kingfisher only if remote image support is retained after testing

### Development tool
- XcodeGen

No other dependency should be added without a clear, documented reason.

## 4. Folder structure

```text
PriceLens/
├── App/
│   ├── PriceLensApp.swift
│   ├── AppContainer.swift
│   ├── AppRootView.swift
│   └── AppRoute.swift
│
├── Core/
│   ├── Camera/
│   ├── Recognition/
│   ├── Networking/
│   ├── Search/
│   │   ├── SearchProvider.swift
│   │   ├── SearchCoordinator.swift
│   │   ├── Google/
│   │   └── Allegro/
│   ├── Matching/
│   ├── Money/
│   ├── Logging/
│   └── Utilities/
│
├── DesignSystem/
│   ├── Components/
│   ├── Modifiers/
│   └── Tokens/
│
├── Features/
│   ├── Scanner/
│   ├── Results/
│   ├── History/
│   └── Settings/
│
├── Models/
│   ├── ProductIdentity.swift
│   ├── Offer.swift
│   ├── SearchSession.swift
│   └── Money.swift
│
├── Persistence/
│   ├── ScanHistoryRecord.swift
│   ├── SearchCacheRecord.swift
│   └── PersistenceController.swift
│
├── Resources/
│   ├── Localizable.xcstrings
│   ├── Assets.xcassets
│   └── ProviderExtractionRules.json
│
└── Supporting/
    └── InfoPlist.xcstrings
```

## 5. Dependency container

Use explicit dependency injection.

Example shape:

```swift
@MainActor
final class AppContainer {
    let scanner: any ScannerProvider
    let recognition: RecognitionService
    let searchCoordinator: SearchCoordinator
    let historyRepository: HistoryRepository
    let settings: AppSettings
}
```

Tests construct a different container with fake providers.

Avoid global static mutable state.

## 6. Scanner abstraction

```swift
protocol ScannerProvider: AnyObject {
    var events: AsyncStream<ScannerEvent> { get }
    func start() async throws
    func stop()
    func capturePhoto() async throws -> UIImage
}
```

Live implementation wraps VisionKit.
Fixture implementation emits deterministic recognized objects.

## 7. Recognition service

Responsibilities:
- normalize barcode,
- normalize OCR text,
- parse monetary values,
- select best current-price candidate,
- build product query candidates,
- detect ambiguity,
- produce `ScanCandidate`.

It must not perform web search.

## 8. Search provider

```swift
protocol SearchProvider: Sendable {
    var id: SearchProviderID { get }

    func search(
        _ request: ProductSearchRequest
    ) async -> ProviderSearchResult
}
```

Never throw provider-specific parser errors all the way into the UI. Return a typed result:

```swift
enum ProviderSearchState: Sendable {
    case success
    case partial
    case fallbackOnly
    case blocked
    case offline
    case failed
}
```

`ProviderSearchResult` includes:
- normalized offers,
- provider state,
- canonical search URL,
- diagnostics safe for DEBUG.

## 9. Search coordinator

Responsibilities:
- receive a product identity,
- build one or more queries,
- search enabled providers concurrently,
- stream partial provider updates,
- deduplicate,
- calculate match confidence,
- sort,
- feed decision engine,
- support cancellation.

Use an async sequence or callback isolated at the coordinator boundary so the UI can render progressive provider results.

## 10. Query strategy

If barcode exists:

```text
Query 1 = exact barcode
```

If zero useful results and OCR identity exists:

```text
Query 2 = brand + model
```

If still zero and title hint exists:

```text
Query 3 = cleaned title hint
```

Do not run all fallbacks simultaneously. Avoid unnecessary requests.

## 11. Search cache

Purpose:
- speed repeated scans,
- reduce provider traffic,
- reduce challenge risk.

Recommended:
- memory cache: 30 minutes
- optional persisted normalized result cache: 6 hours
- history: persistent until user deletes

Cache key:
- provider,
- normalized query,
- region,
- language if materially affects page.

Do not persist raw HTML in Release.

Use an actor for shared cache mutation.

## 12. Networking

Use `URLSession`.

Recommended request policy:
- HTTPS only,
- per-provider timeout about 8 seconds,
- overall search session continues as providers finish,
- one normal attempt,
- at most one parser fallback strategy,
- cancellation propagated immediately when a new scan replaces the previous scan.

Do not implement aggressive retry loops.

## 13. WebKit

`WKWebView` may be used as a fallback page loader when a provider's useful content requires browser rendering.

Rules:
- isolate behind `WebPageLoader`,
- never expose WebKit objects to feature views,
- use ephemeral or controlled website data depending on which gives the most predictable consent behavior,
- do not bypass challenges,
- do not run an invisible browsing farm,
- one navigation per actual user search,
- cancel when the scan is superseded.

## 14. Money

Use Decimal, not Double, for currency math.

```swift
struct Money: Sendable, Hashable {
    let amount: Decimal
    let currencyCode: String
}
```

For MVP:
- normalize PLN / zł / ZŁ / pln to `PLN`,
- support parsing comma and dot decimals,
- support spaces/non-breaking spaces as thousand separators.

Never add different currencies without conversion.

No FX conversion in MVP.

## 15. Decision engine

Pure, testable function:

```swift
func decision(
    storePrice: Money?,
    offers: [Offer]
) -> PurchaseDecision
```

No networking.
No UI strings.
No side effects.

## 16. Matching engine

Inputs:
- scanned barcode,
- OCR brand/model/title,
- result title,
- provider metadata if available.

Normalization:
- Unicode folding,
- case folding,
- punctuation cleanup,
- whitespace collapse,
- tokenization,
- common storage/size token normalization.

High-value tokens:
- model numbers,
- MPN-like strings,
- sizes,
- storage capacities,
- pack counts.

Do not let generic words dominate similarity.

## 17. Persistence

SwiftData models should store:
- timestamp,
- query,
- barcode if available,
- recognized store price,
- best price at time of scan,
- recommendation,
- last successful provider summary.

Do not persist:
- camera photos,
- whole Google pages,
- whole Allegro pages,
- browser cookies as application data.

## 18. Observability

Use `Logger`.

Subsystem examples:
- `scanner`
- `recognition`
- `search.google`
- `search.allegro`
- `matching`
- `persistence`

Release logs must not include raw HTML or images.

## 19. Configuration

Central `AppConfig`:
- default region,
- provider timeouts,
- recommendation thresholds,
- cache TTL,
- scanner stabilization interval,
- feature flags.

Do not scatter constants.

## 20. Build configurations

### Debug
Includes:
- fixture providers,
- diagnostics,
- raw selector testing,
- provider state inspector,
- optional save-fixture action.

### Release
Excludes:
- fixture switching UI,
- raw provider HTML visibility,
- developer diagnostics.
