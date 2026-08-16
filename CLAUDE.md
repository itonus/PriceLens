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
