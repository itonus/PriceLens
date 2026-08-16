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
