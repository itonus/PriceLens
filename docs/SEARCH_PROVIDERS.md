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
