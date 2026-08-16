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
