import Foundation

/// Detects response class: normal page vs consent/challenge/blocked.
/// We never bypass challenges — we classify and fall back.
enum PageClassifier {

    enum Classification: Sendable, Equatable {
        case content
        case consent
        case challenge
        case blocked
        case unknown
    }

    static func classify(html: String, httpStatus: Int?) -> Classification {
        if let status = httpStatus {
            if status == 403 || status == 401 { return .blocked }
            if status == 429 { return .challenge }
        }

        // Check a bounded prefix/suffix; challenge markers are usually near the top.
        let lower = html.lowercased()
        let probe = String(lower.prefix(60_000))

        let challengeMarkers = [
            "unusual traffic", "/sorry/", "recaptcha", "captcha",
            "please enable js and disable any ad blocker", // DataDome (Allegro)
            "datadome", "cf-challenge", "cf-error", "just a moment...",
            "enablejs", "httpservice/retry" // Google JS-gated shell
        ]
        if challengeMarkers.contains(where: { probe.contains($0) }) {
            return .challenge
        }

        let consentMarkers = [
            "consent.google", "before you continue", "przed kontynuacją",
            "accept all", "zaakceptuj wszystko", "privacy reminder"
        ]
        if consentMarkers.contains(where: { probe.contains($0) }) {
            return .consent
        }

        return html.count > 400 ? .content : .unknown
    }
}
