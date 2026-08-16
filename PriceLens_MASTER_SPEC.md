---

# FILE: START_HERE.md

# PriceLens — Start Here

**Status:** implementation specification  
**Research date:** 2026-08-17  
**Product type:** standalone iPhone application  
**Working project name:** `PriceLens`  
**Primary distribution:** local device development, then TestFlight if an Apple Developer Program membership is available  
**UI languages:** English and Russian  
**Store/search region for MVP:** Poland / PLN  
**Backend:** none  
**Paid APIs:** none  
**Accounts:** none

## Product in one sentence

PriceLens lets a person point an iPhone camera at a product or price label in a physical store, automatically identify the product and current shelf price, search Google and Allegro, normalize the available offers, and immediately answer whether buying the product in the store is financially sensible.

The product is not a generic shopping browser. The core value is a fast purchase decision.

## Mandatory first-run experience

1. User launches PriceLens.
2. Camera is the first functional screen.
3. User grants camera permission.
4. The app immediately begins recognizing:
   - UPC-A
   - UPC-E
   - EAN-8
   - EAN-13
   - Code 39 / Code 93 / Code 128 where practical
   - QR
   - Data Matrix
   - text
   - monetary values
5. Detected items are highlighted in the live camera view.
6. When a stable product identity is available, PriceLens automatically starts Google and Allegro searches.
7. If a likely shelf price is visible, it is associated with the scan and shown as "Store price".
8. Results appear in a native bottom sheet over the camera.
9. User sees the decision before the full result list:
   - Store price
   - Best comparable online price
   - Absolute saving
   - Percentage saving
   - Recommendation
10. The user can edit the detected product query or store price.
11. The user can open an offer in an in-app Safari view or system browser.
12. The scan can be saved automatically to local History.

The main flow must not require login, onboarding pages, category selection, provider selection, or a shutter button.

## Read these files in this order

1. `CLAUDE.md`
2. `docs/PRODUCT_SPEC.md`
3. `docs/UX_UI_SPEC.md`
4. `docs/TECHNICAL_ARCHITECTURE.md`
5. `docs/SCANNER_AND_RECOGNITION.md`
6. `docs/SEARCH_PROVIDERS.md`
7. `docs/LOCALIZATION_AND_PERSISTENCE.md`
8. `docs/QA_AND_ACCEPTANCE.md`
9. `docs/TESTFLIGHT_AND_RELEASE.md`
10. `docs/RESEARCH_AND_CONSTRAINTS.md`

## Non-negotiable constraints

- No backend.
- No paid service.
- No cloud database.
- No account/login.
- No LLM API.
- Do not upload camera video.
- Do not persist captured photos unless explicitly needed for a debug fixture and only in DEBUG builds.
- Search must be executed from the device.
- Google and Allegro are the only MVP search sources.
- The app must remain useful when structured extraction from either provider fails.
- English and Russian UI must both be complete before the build is considered done.
- The design must be native Apple-first, not a cross-platform imitation.
- Build and test on simulator plus a real iPhone when available.
- Do not declare the work complete because the project compiles. Functional acceptance tests in `QA_AND_ACCEPTANCE.md` must pass.

## Important feasibility note

There is no suitable official zero-cost public Google Shopping API for this use case, and Allegro's former public offer-listing API is no longer available. Therefore the standalone MVP uses a replaceable, best-effort local web extraction layer with strict fallbacks.

This is acceptable for a private TestFlight prototype. It must not be treated as a stable production integration contract.

## Definition of success for the first beta

The beta is successful if, during a normal store visit, a tester can:

1. launch the app,
2. point it at a common retail product,
3. have a barcode or product text recognized,
4. optionally have the shelf price detected,
5. see Google and/or Allegro search progress automatically,
6. receive at least usable extracted offers when the provider page is parsable,
7. otherwise tap a provider fallback and land on the exact pre-filled Google or Allegro search,
8. compare the in-store price with online results,
9. open the preferred offer,
10. repeat the scan without restarting the application.

The experience should feel immediate even when the network is not.


---

# FILE: CLAUDE.md

# CLAUDE.md — Mandatory Agent Instructions for PriceLens

You are implementing a complete iPhone application named **PriceLens**.

Treat every document under `/docs` as the product contract. Read all of them before making architecture decisions.

## 1. Mission

Create a polished, native, standalone iPhone application that lets a user scan a physical product or shelf label and instantly compare the store price against Google and Allegro.

The application must:
- look and behave like a current first-party-quality iOS application,
- have an exceptionally fast scanner-first flow,
- support English and Russian,
- require no backend,
- require no paid API,
- store user data only on the device,
- build cleanly,
- contain automated tests,
- work on a real device,
- degrade gracefully when Google or Allegro changes its web markup.

Do not stop at scaffolding, mocks, placeholders, or TODOs.

## 2. Decision authority

Do not ask the user routine development questions that are already answered by the specification.

Use these defaults:
- project name: `PriceLens`
- platform: iPhone
- primary orientation: portrait
- UI: SwiftUI
- minimum deployment target: iOS 18
- enable native iOS 26+ Liquid Glass effects conditionally
- architecture: feature-oriented, protocol-driven, async/await
- persistence: SwiftData
- unit testing: Swift Testing
- UI testing: XCTest/XCUIAutomation
- package management: Swift Package Manager
- project generation: XcodeGen when available
- search region: Poland
- primary result currency: PLN
- default provider state: Google ON, Allegro ON
- default app language: System; support explicit English and Russian override
- no analytics SDK
- no crash-reporting SDK
- no backend
- no Firebase
- no Supabase
- no CloudKit
- no paid data provider
- no LLM API

Only block on the user if a genuinely external credential is required for signing/distribution and cannot be inferred from the local Xcode environment.

## 3. Development workflow

### Phase 0 — inspect the machine

Run and record:
- `sw_vers`
- `xcodebuild -version`
- `xcrun simctl list devices available`
- `git --version`
- `brew --version` if Homebrew exists
- `xcodegen --version` if XcodeGen exists

Use the latest stable installed Xcode. Do not require a beta Xcode unless the project cannot otherwise compile.

If XcodeGen is missing and Homebrew is available:
```bash
brew install xcodegen
```

If Homebrew is not available, create the Xcode project using another deterministic method rather than spending time installing an unrelated toolchain.

### Phase 1 — repository bootstrap

Create a git repository.

Expected high-level structure:

```text
PriceLens/
├── CLAUDE.md
├── README.md
├── project.yml
├── PriceLens/
│   ├── App/
│   ├── Core/
│   ├── DesignSystem/
│   ├── Features/
│   ├── Models/
│   ├── Persistence/
│   ├── Resources/
│   └── Supporting/
├── PriceLensTests/
├── PriceLensUITests/
├── TestFixtures/
└── docs/
```

Use one app target, one unit-test target, and one UI-test target.

Generate a shared scheme named `PriceLens`.

### Phase 2 — build foundations

Implement first:
- dependency container,
- design tokens,
- models,
- localization infrastructure,
- persistence models,
- search protocols,
- fixture scanner/search providers for previews and UI tests.

The app must compile before scanner integration begins.

### Phase 3 — scanner

Implement native scanner according to `SCANNER_AND_RECOGNITION.md`.

The scanner must be testable without a physical camera by injecting a `ScannerProvider` protocol implementation.

### Phase 4 — search

Implement `GoogleWebSearchProvider` and `AllegroWebSearchProvider`.

The web adapters are the unstable edge of the system. Isolate them completely from the rest of the app.

Never spread provider-specific DOM selectors through view models or views.

### Phase 5 — decision UI

Implement the live result sheet, unified offer list, recommendation, editing, retry, provider status, and fallbacks.

### Phase 6 — history/settings/localization

Complete both languages, local history, provider toggles, language setting, and debug tools.

### Phase 7 — verification

Run:
```bash
xcodegen generate
xcodebuild -project PriceLens.xcodeproj -scheme PriceLens -destination 'platform=iOS Simulator,name=<available iPhone simulator>' build
xcodebuild -project PriceLens.xcodeproj -scheme PriceLens -destination 'platform=iOS Simulator,name=<available iPhone simulator>' test
```

If the exact simulator name differs, select one returned by `simctl`.

Fix all compiler errors and all failing tests.

Do not accept warnings that indicate correctness, concurrency, localization, privacy, or deprecated-API problems.

### Phase 8 — physical device

If an iPhone is connected and signing can be configured:
- build and run on the physical device,
- verify camera permission,
- verify live barcode scan,
- verify text and price recognition,
- verify Google search,
- verify Allegro search,
- verify provider fallback,
- verify English,
- verify Russian,
- verify light/dark mode,
- verify app relaunch and history persistence.

### Phase 9 — beta readiness

Only after all acceptance checks pass:
- archive a Release build,
- verify app icon and launch appearance,
- verify camera usage description in both languages,
- verify no DEBUG controls appear in Release,
- prepare TestFlight metadata.

## 4. Required engineering principles

### Concurrency
Use structured concurrency:
- `async/await`
- `Task`
- `withTaskGroup` or `async let` for parallel providers
- actors for mutable shared caches/state where appropriate

Avoid callback pyramids.
Avoid Combine unless a native API forces it.

### State
Prefer Swift Observation (`@Observable`) and normal SwiftUI state.
Keep view models small and feature-specific.

### Dependency injection
Do not use a global singleton service locator.

Dependencies should be injectable so:
- live providers run on device,
- fixtures run in previews,
- deterministic fake providers run in tests.

### Networking
Use `URLSession`.
Do not add Alamofire.

### HTML parsing
Use SwiftSoup through Swift Package Manager.

### Remote images
Use Kingfisher if extracted provider images prove useful and reliable.
If image URLs are unreliable or provider-sensitive, omit product images rather than making the card unstable.

### Persistence
Use SwiftData only for local, user-visible or performance-relevant data.
Do not persist raw provider HTML except DEBUG fixture capture explicitly initiated by a developer.

### Logging
Use `OSLog`.
Never log camera images or sensitive full HTML in Release.

### Accessibility
Every actionable element must have:
- accessible label,
- accessible value where relevant,
- sufficient hit target,
- Dynamic Type support.

Respect:
- Reduce Motion
- Reduce Transparency
- dark mode
- increased contrast

## 5. UI rule

Do not create a custom "skin" framework.

Use native SwiftUI components and Apple materials. On iOS 26+ adopt Liquid Glass for controls, navigation, floating toolbars, and transition surfaces. Do not make every product card glass.

Prefer:
- system typography,
- SF Symbols for in-app controls,
- semantic system colors,
- native sheets,
- native menus,
- native haptics,
- native animations,
- content-first hierarchy.

The camera and product/price information are the visual content. Chrome must stay minimal.

## 6. Search-provider rule

Google and Allegro extraction must be treated as **best-effort**.

Provider contract:
1. attempt structured extraction locally,
2. return normalized offers when possible,
3. detect blocked/consent/challenge pages,
4. never bypass CAPTCHAs,
5. never hammer a provider,
6. cache recent identical searches,
7. show source status to the UI,
8. always return the provider search URL,
9. when extraction fails, provide a one-tap "Open Google" / "Open Allegro" fallback.

A provider markup change must not crash the app.

## 7. Never fake success

Do not:
- hardcode fake live prices,
- claim an offer is an exact match without evidence,
- report shipping as free when unknown,
- report a total price when delivery price is unknown,
- mark a provider as successful when only the fallback URL exists,
- silently swallow provider failures.

Use fixture data only in previews, unit tests, UI tests, or an explicit DEBUG demo mode.

## 8. Completion report

At the end of implementation produce `IMPLEMENTATION_REPORT.md` containing:
- Xcode/macOS versions,
- supported iOS target,
- packages and pinned versions,
- implemented features,
- test commands and results,
- physical-device tests performed,
- known provider extraction limitations,
- TestFlight readiness,
- any signing step that still requires the owner.

Do not write "done" until the QA checklist is actually satisfied.


---

# FILE: docs/PRODUCT_SPEC.md

# Product Specification

## 1. Product objective

PriceLens reduces impulse purchases by turning a store shelf into an immediate price-comparison decision.

The app answers:

> Is it worth buying this exact or highly comparable product here, at this price, right now?

The primary value is **decision speed**, not browsing depth.

## 2. Target users

MVP is for the owner, spouse, and a small number of trusted testers.

Assumptions:
- iPhone users,
- mostly shopping in Poland,
- results in PLN are most important,
- Google and Allegro cover enough online discovery for the beta,
- users are comfortable opening a provider page to complete a purchase,
- no account or cross-device synchronization is needed.

## 3. Product principles

### 3.1 Camera first
The app launches into the scanner.

### 3.2 Automatic before manual
Automatic scan, price recognition, product query creation, and provider search should happen before asking the user to type.

### 3.3 Decision before list
Show "buy here / fair / better online" before showing ten product cards.

### 3.4 Honest matching
Do not present a merely similar item as the same product.

### 3.5 Minimal interaction
The normal successful path should require zero or one taps before results.

### 3.6 Graceful failure
A Google markup change is not an application failure. The user must still be able to open the exact search.

### 3.7 Local first
All scanner recognition and app data stay on-device.

## 4. User journeys

### Journey A — barcode and price both visible

1. Open app.
2. Camera starts.
3. EAN/UPC bounding box appears.
4. Price bounding box appears.
5. Barcode remains stable long enough to lock.
6. App gives success haptic.
7. Search begins automatically.
8. Store price is associated automatically.
9. Bottom sheet appears.
10. First extracted offer arrives.
11. Decision updates.
12. User expands sheet to see all offers.
13. User opens one offer.

### Journey B — barcode visible, no shelf price

Same as A, except:
- comparison result can still be shown,
- header says "Add store price",
- user taps store-price field and enters the price,
- decision appears immediately.

### Journey C — no barcode, product model text visible

1. App recognizes text such as:
   - SONY
   - WH-1000XM6
   - 1 799,00 zł
2. Query builder identifies a strong model token.
3. App searches `Sony WH-1000XM6`.
4. Results appear as likely matches.
5. User can tap the recognized query and edit it.

### Journey D — several items are visible

Do not automatically lock to an arbitrary product if multiple viable barcodes exist.

Show highlights. The item closest to the center receives stronger visual emphasis.

If ambiguity persists:
- show "Tap a product",
- let the user tap the intended bounding box,
- then lock and search.

### Journey E — provider parser fails

1. Google returns challenge/unknown markup.
2. Google provider status becomes `fallbackOnly`.
3. Allegro results can still appear.
4. Results screen shows:
   - extracted Allegro offers,
   - "Open Google results" action.
5. No error modal blocks the user.

### Journey F — no internet

Show:
- recognized product identity,
- store price,
- clear offline state,
- retry action.

Keep scanner functional.

## 5. Functional scope

### Scanner
- live barcode recognition,
- QR/Data Matrix recognition,
- live text recognition,
- currency recognition,
- animated highlights,
- scan lock/debounce,
- tap-to-select recognized item,
- torch control,
- optional manual text search,
- camera permission states,
- unsupported-device fallback.

### Recognition
- barcode normalization,
- OCR text cleanup,
- monetary value parsing,
- model-token heuristics,
- price-to-product spatial association,
- editable query,
- editable store price.

### Search
- Google on-device adapter,
- Allegro on-device adapter,
- concurrent execution,
- provider timeout,
- cancellation,
- query fallback,
- in-memory and local cache,
- normalized result model,
- duplicate removal.

### Result comparison
- unified offer list,
- provider badge,
- product title,
- item price,
- known delivery price,
- total price only when calculable,
- match confidence,
- best eligible offer,
- savings,
- recommendation,
- provider fallback links.

### History
- recent scans,
- local only,
- re-run search,
- delete one,
- clear all.

### Settings
- language,
- search providers,
- clear history,
- privacy/about,
- DEBUG provider diagnostics in debug builds only.

## 6. Explicitly outside MVP

Do not build:
- backend,
- user registration,
- account,
- social features,
- coupons,
- cashback,
- checkout,
- payment,
- affiliate tracking,
- price alerts,
- cloud sync,
- Android,
- browser extension,
- AI chat,
- reviews aggregation,
- full product catalog browsing,
- public App Store monetization.

## 7. Recommendation model

Recommendation is calculated only if:
- a valid store price exists,
- at least one comparable online offer exists,
- currency is compatible,
- offer is not classified as weak/uncertain,
- price is numerically valid.

Recommended configurable thresholds:

```text
store <= bestComparable * 1.05
    => GOOD HERE

store <= bestComparable * 1.10
    => FAIR PRICE

store > bestComparable * 1.10
    => BETTER ONLINE
```

The UI should also show the underlying numbers so the recommendation is never opaque.

If confidence is insufficient:
- show prices,
- do not show a strong recommendation,
- use "Compare carefully".

## 8. Match confidence

Use:
- `exact`
- `high`
- `medium`
- `low`

Only `exact` and `high` may influence the default purchase recommendation.

### Exact
Evidence such as an identical GTIN/EAN/UPC or an unambiguous exact model/MPN identity.

### High
Brand + exact model + compatible variant tokens.

### Medium
Strong title similarity but incomplete variant evidence.

### Low
Keyword similarity only.

If the provider page does not expose enough metadata, be conservative.

## 9. Sorting

Default order:
1. exact/high confidence,
2. calculable total delivered price ascending,
3. item price ascending if shipping is unknown,
4. provider result order as a final tie-breaker.

A cheaper `medium` result must not jump above a slightly more expensive `exact` result by default.

User-visible optional sort menu:
- Best match
- Lowest item price
- Lowest known total

## 10. Product identity

Canonical in-memory identity:

```swift
struct ProductIdentity: Sendable, Hashable {
    var barcode: String?
    var brand: String?
    var model: String?
    var titleHint: String?
    var rawRecognizedText: [String]
    var query: String
}
```

Do not require a global product database for MVP.

## 11. Offer model

```swift
struct Offer: Identifiable, Sendable, Hashable {
    let id: String
    let provider: SearchProviderID
    let title: String
    let productURL: URL
    let imageURL: URL?
    let itemPrice: Money
    let deliveryPrice: Money?
    let totalPrice: Money?
    let seller: String?
    let matchConfidence: MatchConfidence
    let extractionConfidence: Double
}
```

## 12. Analytics

No analytics SDK.

For the private beta, product quality is evaluated through:
- direct tester feedback,
- TestFlight crashes,
- deterministic provider diagnostics,
- DEBUG logs.


---

# FILE: docs/UX_UI_SPEC.md

# UX and UI Specification

## 1. Design direction

PriceLens should look unmistakably native to current iOS.

Visual characteristics:
- camera-led experience,
- extremely low chrome,
- crisp system typography,
- floating controls,
- smooth native sheet transitions,
- restrained use of Liquid Glass on iOS 26+,
- content cards that remain readable and stable,
- no generic "startup gradient dashboard",
- no permanent tab bar in the MVP.

The UI should feel closer to Apple's Camera / Wallet / Maps interaction quality than to a cross-platform shopping app.

## 2. Navigation model

No tab bar.

Primary navigation:
- root: Scanner
- top-leading: History
- top-trailing: Settings
- scan result: native bottom sheet
- offer: Safari view / external browser

This keeps the entire core experience on one visual surface.

## 3. Scanner screen

### Full-screen composition

Layer stack:

```text
Camera feed
    ↓
Subtle ROI / focus guidance
    ↓
Recognized-item overlays
    ↓
Top floating controls
    ↓
Bottom scanner state capsule
    ↓
Result sheet when applicable
```

### Top controls
Use compact circular/glass buttons:
- history icon
- torch when supported
- settings icon

Do not place a large navigation title over the camera.

### Focus affordance
Use four corner brackets around a central scan region.

Animation:
- slow, subtle scan sheen or focus pulse while searching,
- stop/reduce motion when a product is locked,
- do not use constant aggressive laser animations.

### Recognized barcode
Draw a rounded rectangle matched to item bounds.

States:
- detected: thin animated outline
- candidate: stronger outline + small label
- locked: short success animation + haptic

### Recognized price
Use a smaller pill attached near the recognized bounds:
`399,99 zł`

A price is a candidate until associated with the selected product.

### Scanner status capsule
Examples:
- `Point at a product`
- `Barcode found`
- `Reading label…`
- `Searching Google + Allegro…`
- `No connection`

On iOS 26+ this is an appropriate Liquid Glass surface.

### Manual fallback
A compact "Type instead" action must be available without leaving the scanner.

## 4. Lock transition

When the product locks:
1. scanning highlight completes,
2. success haptic fires,
3. camera remains visible,
4. search status capsule transitions,
5. result bottom sheet appears.

Use matched geometry / glass transition where supported.
Do not flash the whole screen.

## 5. Result bottom sheet

Use native SwiftUI sheet detents.

Recommended states:
- compact/peek,
- medium,
- large.

### Peek content

The first view should answer the purchase question.

Example:

```text
SONY WH-1000XM6
Likely exact model

STORE
1 799 zł

BEST ONLINE
1 549 zł

SAVE
250 zł · 13.9%

BETTER ONLINE

Google  •  Allegro searching/complete status
```

Primary action:
`View offers`

Secondary:
`Edit`

If store price is missing:
`Add store price`

### Expanded content

Header:
- editable product query
- editable store price
- provider status

Offer list:
- cards
- sort menu
- provider filter optional only if useful

Footer:
- rescan
- provider fallbacks when extraction failed

## 6. Offer card

Hierarchy:

```text
[Source badge]              [Match badge]

Product title, max 2 lines

1 549,00 zł
+ 0 zł delivery
1 549,00 zł total

Seller if useful

                              Open
```

Rules:
- item price is the dominant number,
- show total only when actually calculable,
- do not invent delivery,
- no star ratings in MVP,
- no dense badges,
- no giant marketplace logos.

### Match badges
- `Exact`
- `High match`
- `Possible match`

Do not use "Exact" unless evidence meets the matching rules.

## 7. Decision visual states

Use semantic system color treatment, not hard-coded neon branding.

### GOOD HERE
Calm positive treatment.
Copy:
- English: `Good price here`
- Russian: `Хорошая цена здесь`

### FAIR PRICE
Neutral treatment.
- English: `Fair price`
- Russian: `Нормальная цена`

### BETTER ONLINE
Attention treatment, not alarm red unless accessibility/semantic reason.
- English: `Better online`
- Russian: `В интернете выгоднее`

### UNCERTAIN
- English: `Compare carefully`
- Russian: `Проверьте предложения`

## 8. Animation specification

Use spring animations sparingly.

Required:
- bounding box appearance,
- scanner lock,
- bottom status capsule state transition,
- result sheet presentation,
- offer cards appearing progressively,
- recommendation number transition when best price changes.

Recommended:
- `.contentTransition(.numericText())` for changing prices where available,
- native spring with short duration,
- matched geometry for scanner-state-to-result transitions,
- `.sensoryFeedback(.success, trigger:)` or equivalent native haptic.

### Reduce Motion
If Reduce Motion is enabled:
- remove scan-line movement,
- replace morphs with opacity,
- avoid large scale transforms.

## 9. Liquid Glass policy

On iOS 26+:
Use Liquid Glass for:
- floating camera controls,
- scanner state capsule,
- compact action bars,
- select navigation/transitional surfaces.

Do not use Liquid Glass for:
- every offer card,
- long content backgrounds,
- every text container.

On iOS 18–25:
Use system material fallback such as thin/ultra-thin material with equivalent hierarchy.

All iOS-version-specific effects must be isolated behind reusable design-system components.

## 10. Design-system components

Create:
- `GlassControl`
- `FloatingIconButton`
- `ScannerStatusCapsule`
- `RecognitionOverlay`
- `PriceValueView`
- `DecisionBadge`
- `ProviderStatusChip`
- `OfferCard`
- `EmptyState`
- `InlineErrorState`

Do not create a third-party theme layer.

## 11. Typography

Use system fonts and Dynamic Type.

Suggested semantic styles:
- product name: `.headline`
- hero price: `.system(.title, design: .rounded, weight: .semibold)` only if it remains accessible
- savings: `.title2` or `.headline`
- metadata: `.subheadline`
- chips: `.caption`

Do not lock font sizes with arbitrary pixels unless necessary for scanner overlays.

## 12. Dark mode

Fully support system dark mode.

Do not design a separate brand palette that breaks semantic contrast.

Camera overlays must maintain contrast against both bright packaging and dark shelves using:
- background blur/material where necessary,
- stroke plus shadow,
- adaptive text backing.

## 13. Accessibility

Required:
- VoiceOver labels for scan state and actions,
- logical focus order on sheets,
- price spoken with currency,
- no information encoded only by color,
- Dynamic Type without clipping,
- minimum comfortable hit sizes,
- accessible result-change announcement after scan/search completion.

## 14. Loading and progressive results

Do not block until both providers finish.

If Allegro returns first, show it.
If Google arrives later, merge and re-sort with a subtle animation.

Header provider status example:
- Google: Searching
- Allegro: 6 offers

If one provider fails:
- keep successful provider data,
- expose fallback action for the failed provider.

## 15. Error UX

Never show raw networking errors as modal alerts during scanning.

Use inline states:
- `Google results couldn't be read`
- `Open Google`
- `Retry`

Camera remains available.

Use modal alert only for permissions or truly blocking user decisions.

## 16. History screen

Simple NavigationStack list.

Each row:
- product query/title,
- store price if known,
- best price from last run if known,
- date/time,
- small decision badge.

Tap:
- opens result screen and re-runs search.

Swipe:
- delete.

Toolbar:
- Clear history.

## 17. Settings screen

Sections:

### Language
- System
- English
- Русский

### Search
- Google toggle
- Allegro toggle

At least one provider must remain enabled.

### Data
- Clear history

### About
- privacy
- experimental search notice
- version/build number

DEBUG only:
- Provider diagnostics
- Use fixture data
- Export current extraction fixture


---

# FILE: docs/TECHNICAL_ARCHITECTURE.md

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


---

# FILE: docs/SCANNER_AND_RECOGNITION.md

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


---

# FILE: docs/SEARCH_PROVIDERS.md

# Search Providers Specification

## 1. Why this layer is special

The MVP requires:
- no backend,
- no paid API,
- Google,
- Allegro,
- unified results.

As of the research date, neither Google nor Allegro exposes a suitable official free public product-search API for this exact use case.

Therefore both providers are **experimental web adapters**.

The rest of the app must treat provider extraction as unreliable external input.

## 2. Core protocol

```swift
enum SearchProviderID: String, Codable, Sendable {
    case google
    case allegro
}

struct ProductSearchRequest: Sendable {
    let identity: ProductIdentity
    let query: String
    let countryCode: String
    let currencyCode: String
    let preferredLanguage: String
}

struct ProviderSearchResult: Sendable {
    let provider: SearchProviderID
    let state: ProviderSearchState
    let searchURL: URL
    let offers: [OfferCandidate]
    let duration: Duration
    let debugSummary: String?
}
```

## 3. Provider pipeline

Each provider should implement:

```text
Build canonical search URL
        ↓
Check normalized cache
        ↓
Load page using URLSession
        ↓
Detect response class
        ↓
Try structured-data parser
        ↓
Try provider DOM parser
        ↓
If rendering is required, optional WKWebView strategy
        ↓
Normalize offers
        ↓
Return success / partial / fallbackOnly
```

At every step the canonical search URL is retained.

## 4. Do not bypass anti-bot protections

If the provider returns:
- CAPTCHA,
- bot challenge,
- explicit blocked page,
- consent flow that cannot be safely completed,
- unknown security interstitial,

do not automate around it.

Return a typed provider state and give the user the normal provider page.

## 5. Traffic policy

This app is for human-triggered searches.

Rules:
- one search session per locked scan,
- debounce repeated identical scans,
- cache identical provider queries,
- no background crawling,
- no prefetching arbitrary products,
- no bulk indexing,
- no infinite retries.

## 6. Google provider

### Canonical goal
Search Google Shopping/product-oriented results for:
- exact barcode first,
- then brand + model.

The adapter may use a standard Google search URL with shopping-oriented parameters that are verified during implementation.

Do not hardcode the entire app to one parameter convention. Keep URL construction in one type:

```swift
struct GoogleSearchURLBuilder
```

### Extraction order
1. recognized structured data if available,
2. stable semantic links/text in server HTML,
3. browser-rendered DOM if required,
4. fallback-only.

Extract only what can be confidently derived:
- title,
- price,
- seller/source,
- product URL,
- delivery if explicitly present,
- image URL if stable.

### Google fallback
Always provide:
`Open Google results`

This action opens the exact query.

## 7. Allegro provider

### Important current constraint
Do not implement the old public `GET /offers/listing` REST API. Current Allegro documentation marks public access to that resource as unavailable.

Do not waste time registering OAuth credentials to recover this endpoint.

### Canonical search
Use the normal consumer Allegro search URL for the requested query.

Keep URL construction centralized:

```swift
struct AllegroSearchURLBuilder
```

### Extraction
Prefer, in order:
1. structured data embedded in HTML,
2. stable semantic product anchors and prices,
3. browser-rendered DOM if necessary,
4. fallback-only.

Extract:
- title,
- item price,
- URL,
- seller only when reliable,
- delivery only if explicitly represented and tied to the offer,
- image URL only if reliable.

### Allegro fallback
Always provide:
`Open Allegro results`

## 8. HTML parser architecture

Use SwiftSoup.

Do not write parsing directly inside the provider.

Create:
- `StructuredDataExtractor`
- `GoogleOfferHTMLParser`
- `AllegroOfferHTMLParser`
- `PriceParser`
- `URLNormalizer`

Parser inputs:
- raw HTML string,
- base URL.

Parser outputs:
- `[OfferCandidate]`
- parser diagnostics.

## 9. Structured-data-first strategy

Search for:
- `application/ld+json`
- obvious structured state payloads

Decode tolerant JSON into intermediate structures.

Never assume a single JSON-LD object.
Support:
- object,
- array,
- `@graph`.

Only use Product/Offer-shaped data when fields can be mapped confidently.

## 10. DOM extraction rules

Provider markup will change.

Required architecture:
- selectors contained within provider parser,
- selector recipes represented as small ordered strategies,
- parser unit tests use saved HTML fixtures,
- unknown markup returns zero candidates instead of crashing.

Good:
```swift
for strategy in strategies {
    if let offers = try? strategy.parse(document), !offers.isEmpty {
        return offers
    }
}
```

Bad:
- force unwraps,
- index assumptions,
- parsing based only on obfuscated CSS class names spread throughout code.

Prefer:
- semantic attributes,
- links,
- accessible labels,
- structured scripts,
- stable URL patterns.

## 11. Fixture workflow

During implementation on the Mac:
1. manually perform representative Google and Allegro searches,
2. inspect received HTML/DOM,
3. save sanitized snapshots to `TestFixtures/Providers/...`,
4. build parsers against fixtures,
5. add regression tests.

Fixtures must cover:
- barcode query,
- model query,
- no results,
- consent/challenge if observed,
- price with comma decimal,
- price with spaced thousands,
- multiple offers.

Do not commit personal cookies.

## 12. Candidate normalization

`OfferCandidate` should preserve raw evidence:

```swift
struct OfferCandidate: Sendable {
    let provider: SearchProviderID
    let title: String
    let url: URL
    let rawPriceText: String
    let parsedItemPrice: Money?
    let rawDeliveryText: String?
    let parsedDeliveryPrice: Money?
    let seller: String?
    let imageURL: URL?
    let evidence: OfferEvidence
}
```

Normalization happens after parsing.

## 13. Deduplication

Within one provider:
- canonicalize URLs,
- remove tracking parameters when safe,
- normalize title,
- merge duplicates that clearly represent the same card.

Across providers:
- do not merge Google and Allegro into one record just because titles match.
- both are useful source evidence.

## 14. Matching

### Barcode query
A result found from a barcode query is not automatically `exact`.

Promote to exact only if:
- result metadata repeats the barcode/GTIN, OR
- a strong exact model identity is proven.

### Model query
High confidence requires:
- exact normalized model token,
- compatible brand when available,
- no conflicting variant token.

### Variant conflicts
Examples:
- 128 GB vs 256 GB
- 0.5 L vs 1.5 L
- pack of 1 vs pack of 4

A conflicting variant must reduce confidence severely.

## 15. Price parsing

Use the shared `PriceParser`.

Do not parse:
- installment/monthly payment as full price,
- crossed-out original price when a current price is available,
- per-unit/kg price as product total,
- coupon savings as product price.

When ambiguous, discard the candidate price instead of guessing.

## 16. Shipping

Rules:
- if explicit numeric delivery cost is present, parse it,
- if explicitly free, `0 PLN`,
- if absent/unknown, `nil`.

`totalPrice` exists only when:
- itemPrice is known,
- deliveryPrice is known.

Do not assume free delivery.

## 17. Result fallback UI contract

Provider states map to UI:

### success
Show offer count.

### partial
Show extracted offers + optional warning in provider status.

### fallbackOnly
Show provider button.

### blocked
Show:
`Google needs to be opened directly`
or equivalent localized message.

### offline
Global offline state.

### failed
Offer retry and provider link.

## 18. Development diagnostics

DEBUG-only provider inspector should show:
- query,
- URL,
- HTTP status,
- loader used,
- parser strategy used,
- offer count,
- detected challenge/consent,
- elapsed time.

Never show this in Release.

## 19. Search session cancellation

When a new scan starts:
- cancel old Google request,
- cancel old Allegro request,
- stop old WebKit navigation,
- ignore late results from old session.

Tag all result updates with a search session UUID.

## 20. Acceptance target

For the beta, "working" does not mean 100% extraction forever.

It means:
- current Google and Allegro pages have a tested extraction strategy at implementation time,
- parser failures never crash,
- both provider fallbacks always work,
- one provider can fail while the other remains usable,
- parser changes are isolated and fixture-testable.


---

# FILE: docs/LOCALIZATION_AND_PERSISTENCE.md

# Localization and Persistence

## 1. UI languages

Required:
- English
- Russian

Use Xcode String Catalogs (`.xcstrings`).

Development language: English.

Every user-facing string must be localizable.

## 2. In-app language preference

Settings:
- System
- English
- Русский

Store preference locally.

Implement language override cleanly at the root environment.

Do not duplicate whole view trees for language variants.

## 3. OCR language is separate

Even if UI is Russian, OCR should still recognize Polish shelf labels.

Scanner OCR language set should include:
- pl-PL
- en-US/en
- ru-RU/ru

## 4. Localization quality

Do not machine-literalize important purchase-decision text without review.

Required baseline translations:

| English | Russian |
|---|---|
| Point at a product | Наведите камеру на товар |
| Barcode found | Штрихкод найден |
| Reading label… | Считываю этикетку… |
| Searching Google + Allegro… | Ищу в Google и Allegro… |
| Store price | Цена в магазине |
| Best online | Лучшая цена онлайн |
| Save | Экономия |
| Good price here | Хорошая цена здесь |
| Fair price | Нормальная цена |
| Better online | В интернете выгоднее |
| Compare carefully | Проверьте предложения |
| Exact | Точное совпадение |
| High match | Высокое совпадение |
| Possible match | Возможное совпадение |
| Open | Открыть |
| Edit | Изменить |
| Add store price | Добавить цену в магазине |
| View offers | Смотреть предложения |
| Rescan | Сканировать снова |
| No connection | Нет подключения |
| Retry | Повторить |
| Type instead | Ввести вручную |
| History | История |
| Settings | Настройки |
| Clear history | Очистить историю |

Agent must complete the catalog for every introduced string.

## 5. Locale-aware money

Display money with `FormatStyle.Currency`.

Use the money object's currency code.

For PLN:
- English may display `PLN` or `zł` according to formatter behavior.
- Russian should remain clear and consistent.

Parsing must accept provider/store source formats independent of the selected UI language.

## 6. SwiftData

Persist scan history locally.

Suggested model:

```swift
@Model
final class ScanHistoryRecord {
    var id: UUID
    var createdAt: Date
    var query: String
    var barcode: String?
    var storePriceAmount: Decimal?
    var storePriceCurrency: String?
    var bestPriceAmount: Decimal?
    var bestPriceCurrency: String?
    var decisionRawValue: String?
}
```

Adjust storage representation if SwiftData/Decimal requires a compatibility wrapper in the chosen Xcode version.

## 7. History retention

Default:
- retain recent history until user clears it.

A practical cap such as 100 or 200 records is acceptable to prevent uncontrolled growth.

If capped:
- delete oldest records automatically,
- do not surprise user with aggressive expiry.

## 8. Search cache

Separate from user history.

Search cache may expire automatically.

Do not expose cache internals in normal Settings.

## 9. Privacy

Normal operation stores:
- recognized text/query,
- barcode,
- typed price,
- normalized offer summary in history.

Normal operation does not store:
- camera frames,
- captured high-resolution product photo,
- full provider HTML,
- location,
- contacts,
- advertising identifiers.

No tracking permission should be requested.

## 10. Camera usage description

Localize `NSCameraUsageDescription`.

English:
`PriceLens uses the camera to recognize product barcodes, labels, and prices for comparison.`

Russian:
`PriceLens использует камеру для распознавания штрихкодов, этикеток и цен, чтобы сравнивать предложения.`

## 11. App-specific language testing

QA must test:
- system English,
- system Russian,
- app override English,
- app override Russian,
- switching language and returning to scanner,
- formatted prices after switch,
- scanner OCR still recognizing Polish text.


---

# FILE: docs/QA_AND_ACCEPTANCE.md

# QA and Acceptance Criteria

## 1. Quality bar

No software can be proven to have zero bugs. The implementation target is:
- no known release-blocking bugs,
- deterministic automated coverage of core business logic,
- fixture coverage of provider parsers,
- successful simulator build/tests,
- successful real-device scanner test,
- graceful behavior for all known provider failures.

The agent must not describe the app as "bug-free" merely because tests pass.

## 2. Automated test suites

### Unit: Money / PriceParser
Cover:
- `399,99 zł`
- `399.99 PLN`
- `1 799,00 zł`
- non-breaking spaces,
- `79 zł`
- free delivery text,
- malformed price,
- installment price rejection where identifiable,
- percent/savings text not parsed as product price.

### Unit: BarcodeNormalizer
Cover:
- whitespace,
- leading zero,
- valid/invalid check digit examples,
- non-digit formats that are allowed for code symbology.

### Unit: ProductQueryBuilder
Cover:
- barcode-only,
- `Sony WH-1000XM6`,
- brand + noisy label,
- no strong model,
- Polish promotional noise,
- Russian/English text.

### Unit: OfferMatcher
Cover:
- exact same model,
- different storage variant,
- different pack quantity,
- same brand but different model,
- generic title only.

### Unit: DecisionEngine
Cover:
- no store price,
- no offers,
- good-here threshold,
- fair threshold,
- better-online threshold,
- medium/low results excluded,
- unknown delivery handling,
- currency mismatch.

### Unit: Sorting
Cover:
- exact vs cheaper medium match,
- known total vs unknown shipping,
- tie handling.

### Provider parser fixtures
For each provider:
- normal successful page fixture,
- no result,
- changed/missing selector,
- malformed card,
- challenge/consent fixture if observed.

Parser must never crash on arbitrary fixture HTML.

## 3. UI test mode

Support launch argument:
`-UITestMode`

Optional:
`-FixtureScenario successfulScan`
`-FixtureScenario noStorePrice`
`-FixtureScenario providerFailure`
`-FixtureScenario offline`

UI tests cover:
- scanner fixture locks,
- result sheet appears,
- offer list expands,
- edit store price,
- recommendation changes,
- open-offer control exists,
- settings language changes,
- history row appears.

## 4. Manual scanner tests on real iPhone

Test at least:

### Barcode
- EAN-13 on normal package,
- small barcode,
- reflective package,
- angled barcode,
- two barcodes in frame.

Expected:
- highlights follow the correct item,
- no repeated search spam,
- ambiguous state permits manual selection.

### Text
- model text on electronics box,
- Polish shelf label,
- English product box,
- Russian text if available.

### Price
- `xx,xx zł`,
- thousands separator,
- multiple prices in frame,
- promotional old/new price.

Expected:
- user can correct any wrong selection.

## 5. Permission tests

### First launch
- camera permission prompt is correctly localized.

### Denied
- manual entry remains usable,
- Settings action works,
- app does not loop permission prompts.

## 6. Network tests

### Normal Wi-Fi
- both providers start concurrently,
- progressive results visible.

### Slow network
- UI stays responsive,
- scanner can be reset,
- provider statuses update.

### Offline
- scanner still works,
- recognized identity remains visible,
- retry appears.

### One provider fails
- other provider results remain.

### Both extraction fail
- Google and Allegro fallback links remain usable.

## 7. Provider live tests

At implementation completion, manually verify current live behavior for:
- one common EAN/GTIN query,
- one exact electronics model,
- one query with no good result.

Record in `IMPLEMENTATION_REPORT.md`:
- date,
- provider,
- query,
- parser strategy,
- outcome.

Do not store account cookies or personal data in repository fixtures.

## 8. Localization tests

Every screen:
- English
- Russian

Check:
- truncation,
- sheet sizes,
- buttons,
- Dynamic Type,
- VoiceOver labels.

No English string may leak into Russian UI except:
- provider trademarks,
- product titles returned by providers,
- technical model identifiers.

## 9. Appearance tests

Test:
- light,
- dark,
- Reduce Motion,
- larger Dynamic Type,
- iOS 26+ Liquid Glass path if simulator/device is available,
- iOS 18 fallback path if available.

## 10. History tests

- successful scan creates record,
- relaunch keeps record,
- tap re-runs query,
- delete removes one,
- clear history clears all.

## 11. Performance goals

These are targets, not reasons to falsify results.

- camera screen ready quickly after permission,
- scan lock occurs without noticeable repeated flicker,
- search starts immediately after lock,
- first provider result is rendered as soon as available,
- scrolling remains 60 fps on modern supported iPhones,
- no main-thread HTML parsing for large pages.

Run parser work off the main actor.

## 12. Crash/error rules

Release-blocking:
- crash on unknown provider markup,
- force unwrap in parser path that can see external data,
- crash when camera permission denied,
- crash on nil/unknown price,
- stale search results applied to a newer scan session,
- language switch crash,
- SwiftData migration/launch crash on current beta schema.

## 13. Acceptance criteria

### AC-1 Scanner-first launch
Given camera access is available, when the app launches, then the live scanner is the primary screen without an intermediate home screen.

### AC-2 Barcode recognition
Given a supported visible retail barcode, when it remains stable, then the app highlights it and creates a product scan candidate.

### AC-3 Automatic search
Given a scan candidate is locked, then enabled Google and Allegro searches start without an additional confirmation tap.

### AC-4 Price recognition
Given a recognizable shelf price is visible near the selected product, then the app proposes it as the store price and allows editing.

### AC-5 Progressive results
When one provider returns before the other, then its offers become visible immediately.

### AC-6 Unified sorting
When offers exist from Google and Allegro, then they appear in one normalized list following matching and price rules.

### AC-7 Honest recommendation
A recommendation is only shown from comparable high-confidence offers with compatible currency.

### AC-8 Provider failure isolation
If Google extraction fails, Allegro results remain usable and Google provides a direct fallback search action, and vice versa.

### AC-9 No backend
All product recognition, provider search orchestration, history, and comparison logic operate on the iPhone.

### AC-10 Localization
All first-party UI is complete in English and Russian.

### AC-11 Local privacy
Normal scanning does not upload or persist camera photos.

### AC-12 History
Completed scan sessions can be reopened from local history.

### AC-13 Testability
Core logic and provider parsers have automated tests; UI tests do not depend on a real camera.

### AC-14 Release build
Release configuration builds successfully without DEBUG-only provider tools.

## 14. Final agent gate

Before stopping:
- build passes,
- tests pass,
- current provider live test performed,
- no known blocker remains,
- implementation report written.

If a live provider parser is currently broken, do not hide it. State it and ensure the direct provider fallback is fully working.


---

# FILE: docs/TESTFLIGHT_AND_RELEASE.md

# TestFlight and Release Guide

## 1. Cost reality

Building and installing the app on the owner's own connected iPhone through Xcode does not require paid App Store distribution membership.

Distributing through TestFlight requires Apple Developer Program capabilities. Apple currently lists the Apple Developer Program at USD 99 per membership year (or local equivalent).

Therefore:
- if the owner already has a paid membership, this project adds no mandatory API/backend cost,
- if the owner does not have a membership, direct personal-device development can still be free, but TestFlight distribution is not a zero-cost path.

## 2. Signing

Use automatic signing.

Keep these values easy to change:
- bundle identifier,
- development team.

Suggested temporary bundle:
`com.<owner-domain-or-name>.PriceLens`

Do not invent a real Team ID.

## 3. Capabilities

MVP should need minimal capabilities.

Expected:
- camera permission only.

Do not enable:
- push notifications,
- iCloud,
- Sign in with Apple,
- tracking,
- background processing,
unless later required.

## 4. Release metadata

Prepare:
- app name: PriceLens (working)
- short TestFlight description
- feedback email supplied by owner
- privacy note
- camera use explanation

## 5. App icon

A valid AppIcon asset is required.

Use an original temporary icon with no third-party marketplace logos and no copied Google/Allegro marks.

Visual concept:
- clean scan-frame motif,
- price/check signal,
- high contrast,
- readable at small size.

## 6. External testers

If spouse/friends are not members of the App Store Connect team, they are external testers.

The first external TestFlight build may require TestFlight App Review.

Prepare "What to Test":
- barcode scanning,
- shelf-price recognition,
- Google/Allegro comparison,
- English/Russian UI,
- wrong-product/wrong-price correction.

## 7. Release checklist

- Release build compiles.
- App icon present.
- Camera description localized.
- No fixture mode visible.
- No developer raw HTML.
- No hardcoded personal test values.
- History clean on fresh install.
- English/Russian checked.
- Provider fallback links verified.
- Google/Allegro trademarks used textually only where needed to identify the service.
- Version/build incremented.

## 8. Archive

Use Xcode Organizer or command-line archive when signing is available.

Do not block normal code completion on TestFlight credentials.

If signing membership is unavailable:
- finish a fully buildable project,
- test through simulator and directly connected iPhone as far as available,
- document the exact remaining distribution step.


---

# FILE: docs/RESEARCH_AND_CONSTRAINTS.md

# Research and Constraints

Verified 2026-08-17.

This file records why the implementation makes certain decisions. Agents should re-check provider behavior if live pages have changed.

## Apple scanner

### VisionKit DataScannerViewController
Apple documents `DataScannerViewController` as a live camera scanner for physical text and machine-readable codes.

Source:
https://developer.apple.com/documentation/visionkit/datascannerviewcontroller

### Scanning data with the camera
VisionKit provides the live video, guidance, recognition, and interaction model for text and codes.

Source:
https://developer.apple.com/documentation/visionkit/scanning-data-with-the-camera/

### High-resolution capture
`DataScannerViewController.capturePhoto()` captures a high-resolution photo of the live video, useful for a secondary OCR pass after scan lock.

Source:
https://developer.apple.com/documentation/visionkit/datascannerviewcontroller/capturephoto()

### Currency recognition
VisionKit supports currency-oriented text recognition through DataScanner text content types.

Source:
https://developer.apple.com/documentation/visionkit/datascannerviewcontroller/textcontenttype

## Apple design

### Liquid Glass
Apple's modern design language uses Liquid Glass as a dynamic material, especially around controls and navigation.

Sources:
https://developer.apple.com/documentation/technologyoverviews/liquid-glass
https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass
https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views

### Material guidance
Apple cautions against using Liquid Glass throughout the content layer. It should preserve a clear distinction between controls and content.

Source:
https://developer.apple.com/design/human-interface-guidelines/materials

### SwiftUI glass API
`glassEffect` / glass button styles are iOS 26+ APIs.

Sources:
https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:)
https://developer.apple.com/documentation/swiftui/glassbuttonstyle

Therefore PriceLens:
- supports iOS 18 minimum,
- conditionally uses native glass on iOS 26+,
- provides a material fallback on earlier iOS.

## Apple localization

Use String Catalogs.

Sources:
https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog
https://developer.apple.com/videos/play/wwdc2023/10155/

## Apple persistence and testing

SwiftData:
https://developer.apple.com/documentation/swiftdata

Swift Testing:
https://developer.apple.com/documentation/testing

## Google constraint

### Custom Search JSON API
Google states that Custom Search JSON API is closed to new customers as of 2026.

Source:
https://developers.google.com/custom-search/v1/overview

This prevents basing a new free prototype on that official API.

### Merchant API / Content API for Shopping
Google's Merchant APIs are for merchants managing their own Merchant Center products/inventory. They are not a general public Google Shopping comparison search API.

Source:
https://developers.google.com/shopping-content/guides/quickstart

Therefore the standalone beta treats Google as a local web-search adapter with direct-search fallback.

## Allegro constraint

Allegro's current REST method list marks public access to:
`GET /offers/listing`
as no longer available.

Source:
https://developer.allegro.pl/tutorials/lista-metod-rest-api-allegro-yPyaj0wG3C4

Allegro REST API otherwise uses OAuth and is strongly oriented toward seller/account resources.

Authentication source:
https://developer.allegro.pl/tutorials/uwierzytelnianie-i-autoryzacja-zlq9e75GdIR

Therefore do not spend MVP time building an OAuth integration expecting public marketplace search from the old listing endpoint.

## TestFlight cost

Apple Developer Program membership is listed at USD 99 per membership year.

Source:
https://developer.apple.com/programs/whats-included/

Apple also states that installing on a personal device using Xcode does not require enrollment, while distribution features require program membership.

Source:
https://developer.apple.com/help/account/membership/program-enrollment/

External TestFlight testing process:
https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/

## Open-source development dependencies

### SwiftSoup
Pure Swift HTML parser.

Source:
https://github.com/scinfu/SwiftSoup

### Kingfisher
Pure Swift image downloading/caching library, MIT licensed.

Source:
https://github.com/onevcat/Kingfisher

Use only if remote images materially improve the UI.

### XcodeGen
Open-source project generation tool with YAML/JSON project specs.

Source:
https://github.com/yonaskolb/XcodeGen

Install via Homebrew when available:
`brew install xcodegen`

## Product risk

The biggest technical risk is not barcode recognition. It is provider web extraction.

Mitigation:
- strict provider boundary,
- parser fixtures,
- structured-data-first parsing,
- graceful fallback URLs,
- local caching,
- low request volume,
- no provider-specific assumptions in the UI,
- no claim that extraction is a permanent supported API.


---

# FILE: PROMPT_FOR_CLAUDE.md

# Prompt to give the main Claude Code / Sonnet development agent

You are the primary implementation agent for the PriceLens iPhone application.

The repository contains `CLAUDE.md` and detailed specifications under `/docs`.

Your task is to implement the entire MVP, not merely propose architecture.

Follow this execution contract:

1. Read `START_HERE.md`, `CLAUDE.md`, and every file under `/docs` before coding.
2. Inspect the local macOS/Xcode environment.
3. Initialize the repository and Xcode project.
4. Use SwiftUI, Swift concurrency, VisionKit, Vision, SwiftData, String Catalogs, Swift Testing, and XCTest UI tests as specified.
5. Keep the app completely standalone. Do not create or depend on any backend.
6. Do not add paid APIs.
7. Implement scanner-first UX with live recognized-item highlighting and native animations.
8. Implement English and Russian UI completely.
9. Implement local Google and Allegro search adapters behind the `SearchProvider` protocol.
10. Treat web extraction as best-effort:
    - structured-data first,
    - provider parser second,
    - optional WKWebView rendered strategy third,
    - direct provider search fallback always.
11. Inspect current Google and Allegro result pages during development and create sanitized HTML fixtures for parser regression tests.
12. Never bypass CAPTCHAs or anti-bot challenges.
13. Never fake live prices or label uncertain products as exact matches.
14. Implement local scan history.
15. Implement DEBUG fixture scenarios so simulator/UI tests do not require a camera.
16. Implement the Apple-current visual design in `UX_UI_SPEC.md`, including conditional iOS 26+ Liquid Glass and proper earlier-iOS material fallback.
17. Run the full build and test suite repeatedly until it passes.
18. If a physical iPhone is connected and signing is available, run and test the real scanner on device.
19. Fix issues discovered by the tests. Do not leave TODO placeholders for required MVP behavior.
20. Produce `IMPLEMENTATION_REPORT.md` with exact evidence of what was built and tested.

Do not stop after creating files.
Do not stop after the first successful compile.
Do not return a theoretical answer instead of implementing.
Do not introduce a backend because Google/Allegro parsing is inconvenient.

The app is complete only when the acceptance criteria in `docs/QA_AND_ACCEPTANCE.md` are satisfied or a specific external blocker is clearly documented.
