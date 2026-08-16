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
