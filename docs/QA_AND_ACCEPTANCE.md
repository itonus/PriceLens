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
