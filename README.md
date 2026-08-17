# PriceLens

Point your iPhone at a product. PriceLens recognizes it, reads the shelf price if one is visible,
and compares it against what the same item costs online.

Native SwiftUI, iOS 18+. No backend, no analytics, no tracking. Everything runs on the device and
your scan history never leaves it.

> **Status: working prototype.** Product identification works well for barcoded groceries. Live
> price extraction is genuinely limited — see [What actually works](#what-actually-works) before
> expecting a finished shopping app. That section is deliberately blunt.

## What it does

- **Scanner-first.** The camera *is* the home screen — no menu to get through first.
- **Live recognition** of barcodes, product text, and prices via VisionKit.
- **Barcode → real product**, resolved against [Open Food Facts](https://openfoodfacts.org)
  (free, no key, no account). Once identified, the search re-runs using the confirmed product name
  rather than whatever OCR happened to read off the packaging.
- **Honest comparison.** A recommendation appears only when there are genuinely comparable
  offers in a compatible currency. Unknown delivery cost is shown as unknown, never as free.
- **Local history** via SwiftData. English and Russian. Light and dark. Dynamic Type. VoiceOver.

## What actually works

Being straight about this matters more than a nice feature list.

| Capability | Status |
|---|---|
| Barcode scanning & normalization | ✅ Works |
| Barcode → product name + image | ✅ Works for food/grocery items |
| Barcode → product for non-food | ⚠️ Often unavailable — Open Food Facts is a *food* database |
| Shelf price OCR + comparison | ✅ Works when a price is legible in frame |
| Allegro offers (with API credentials) | ⚠️ Implemented; needs your own credentials to verify |
| Allegro offers (without credentials) | ❌ Falls back to opening a search link |
| Google Shopping offers | ❌ **Not possible** — see below |
| Local history, i18n, accessibility | ✅ Works |

### Why Google offers don't work

Google's shopping surface returns a JavaScript bootstrap shell to any non-browser client:
HTTP 200, roughly 90 KB, **zero prices and zero structured data**, with `enablejs` and
`httpservice/retry` markers. Results load afterwards over an internal RPC.

Rendering the page in a `WKWebView` was tried and does not help: an ephemeral web view lands on the
consent wall, and **this project will not click through consent or anti-bot challenges.**

So Google is a one-tap fallback link, not a source of in-app offers. Rather than fake it, the app
says "results couldn't be read" and hands you the link.

Allegro's public listing pages are likewise served behind a DataDome interstitial, which is why the
official API is the only supported path for real Allegro offers.

## Requirements

- Xcode 26+, iOS 18.0+ deployment target, Swift 6
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) — the `.xcodeproj`
  is generated and deliberately not committed
- A physical iPhone for camera testing; the simulator has no camera

## Build

```bash
git clone https://github.com/itonus/PriceLens.git
cd PriceLens
xcodegen generate
open PriceLens.xcodeproj
```

Set your own signing team in **Signing & Capabilities** (no Team ID is committed to this repo), then
run. Or from the command line:

```bash
xcodebuild -project PriceLens.xcodeproj -scheme PriceLens \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

### Tests

```bash
xcodebuild -project PriceLens.xcodeproj -scheme PriceLens \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

85 unit tests (Swift Testing) and 7 UI tests (XCUIAutomation). UI tests are fixture-driven and need
no camera or network.

## Allegro API (optional)

Without credentials the app builds and runs; Allegro just falls back to a search link. To get real
Allegro offer cards, see **[docs/ALLEGRO_API_SETUP.md](docs/ALLEGRO_API_SETUP.md)**.

Credentials live in `PriceLens/Resources/Secrets.plist`, which is **gitignored**. Copy
`Secrets.example.plist` to create it. No secrets are committed to this repository.

⚠️ Credentials bundled into an app can be extracted from the binary. That is unavoidable when
calling a credentialed API directly from a client with no server. Use a key you can revoke.

## Architecture

Feature-oriented, protocol-driven, `async/await` throughout.

```
PriceLens/
├── App/            Dependency container, routing, settings
├── Core/
│   ├── Camera/     VisionKit scanner (live + fixture implementations)
│   ├── Recognition/ Barcode normalization, query building, product resolution
│   ├── Money/      Price parsing (PLN formats, separators, false-positive rejection)
│   ├── Matching/   Offer matching, sorting, purchase decision
│   └── Search/     Provider adapters — Google, Allegro — plus caching
├── DesignSystem/   Tokens and reusable components
├── Features/       Scanner, Results, History, Settings
├── Models/         Domain types
└── Persistence/    SwiftData history and search cache
```

Design rules the code sticks to:

- **Provider markup stays quarantined.** DOM selectors live only in the provider adapters. A
  markup change cannot crash the app or leak into view models.
- **Never fake success.** No hardcoded prices, no "exact match" without evidence, no "free
  shipping" when delivery is unknown, no provider marked successful when only a fallback URL exists.
- **Injected dependencies.** Live providers on device, fixtures in previews and tests. No
  singleton service locator.
- **Off-main parsing.** HTML work never blocks the main actor.

## Privacy

- No backend, no analytics SDK, no crash reporting, no ad identifiers.
- Camera frames are analyzed in memory and never uploaded or written to disk.
- Scan history stays on the device in SwiftData.
- Network requests go only to the search providers and Open Food Facts.

## Contributing

Issues and pull requests are welcome. Two things to keep in mind:

1. **No challenge or CAPTCHA bypassing.** Not for Google, not for Allegro, not for anyone. PRs
   doing this will be declined.
2. **No fabricated data.** If a provider can't be read, the UI must say so.

## License

MIT — see [LICENSE](LICENSE).

Google, Allegro, Xbox and other marks belong to their respective owners and are used only to
identify the services and products being compared.
