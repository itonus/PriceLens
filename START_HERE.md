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
