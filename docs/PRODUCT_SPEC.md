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
