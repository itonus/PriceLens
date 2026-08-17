import Foundation

/// Allegro Open API credentials, loaded at runtime from an untracked `Secrets.plist`.
///
/// Nothing secret is committed to this repository. When `Secrets.plist` is absent — which is the
/// normal state for a fresh clone — `isConfigured` is false, the app skips the Allegro API and
/// falls back to opening the Allegro search in the browser. The app stays fully buildable and
/// usable without credentials.
///
/// Setup: see `docs/ALLEGRO_API_SETUP.md`.
///
/// Security note: a `Secrets.plist` bundled into the app ships inside the binary and can be
/// extracted from it. That is inherent to calling a credentialed API directly from a client with
/// no backend. Use a key you can revoke, and never commit the file.
enum AllegroAPICredentials {

    private struct Values: Decodable {
        let clientID: String
        let clientSecret: String
        let userAgent: String
    }

    private static let values: Values? = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let decoded = try? PropertyListDecoder().decode(Values.self, from: data) else {
            return nil
        }
        guard !decoded.clientID.isEmpty,
              !decoded.clientSecret.isEmpty,
              !decoded.userAgent.isEmpty else { return nil }
        return decoded
    }()

    static var clientID: String { values?.clientID ?? "" }
    static var clientSecret: String { values?.clientSecret ?? "" }

    /// Allegro requires a registered User-Agent on every REST call and **blocks the API key**
    /// when it is missing or malformed. Generate it in the Allegro developer console.
    static var userAgent: String { values?.userAgent ?? "" }

    static var isConfigured: Bool { values != nil }
}
