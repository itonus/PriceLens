import Foundation
import Observation

/// User-facing settings: language override and provider toggles. Persisted in UserDefaults.
@Observable
final class AppSettings {
    private let defaults: UserDefaults

    var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: Keys.language)
            defaults.synchronize()
        }
    }

    var isGoogleEnabled: Bool {
        didSet { defaults.set(isGoogleEnabled, forKey: Keys.googleEnabled) }
    }

    var isAllegroEnabled: Bool {
        didSet { defaults.set(isAllegroEnabled, forKey: Keys.allegroEnabled) }
    }

    /// Active locale for formatting (system follows device).
    var activeLocale: Locale { language.locale ?? .autoupdatingCurrent }

    private enum Keys {
        static let language = "settings.language"
        static let googleEnabled = "settings.googleEnabled"
        static let allegroEnabled = "settings.allegroEnabled"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let rawLanguage = defaults.string(forKey: Keys.language) ?? AppLanguage.system.rawValue
        self.language = AppLanguage(rawValue: rawLanguage) ?? .system
        self.isGoogleEnabled = defaults.object(forKey: Keys.googleEnabled) as? Bool ?? true
        self.isAllegroEnabled = defaults.object(forKey: Keys.allegroEnabled) as? Bool ?? true
    }

    /// At least one provider must remain enabled.
    func setProvider(_ provider: SearchProviderID, enabled: Bool) {
        switch provider {
        case .google:
            isGoogleEnabled = enabled
            if !isGoogleEnabled && !isAllegroEnabled { isAllegroEnabled = true }
        case .allegro:
            isAllegroEnabled = enabled
            if !isAllegroEnabled && !isGoogleEnabled { isGoogleEnabled = true }
        }
    }

    func isProviderEnabled(_ provider: SearchProviderID) -> Bool {
        switch provider {
        case .google: return isGoogleEnabled
        case .allegro: return isAllegroEnabled
        }
    }

    /// Localized string lookup honoring the in-app language override.
    /// Views must read `language` (they do via this call site being in a view body
    /// that also renders `settings`-dependent content) to re-render on change.
    func localized(_ key: String) -> String {
        _ = language // observation dependency
        return String(localized: String.LocalizationValue(key), bundle: language.resolvedBundle)
    }
}
