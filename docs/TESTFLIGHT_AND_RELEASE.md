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
