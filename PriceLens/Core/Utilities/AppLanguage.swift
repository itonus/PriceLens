import Foundation

enum AppLanguage: String, CaseIterable, Sendable, Identifiable {
    case system
    case english = "en"
    case russian = "ru"

    var id: String { rawValue }

    /// Bundle used for string lookup. nil = system behavior via Bundle.main.
    var resolvedBundle: Bundle? {
        switch self {
        case .system:
            return nil
        case .english:
            return Bundle.main.path(forResource: "en", ofType: "lproj").flatMap(Bundle.init(path:))
        case .russian:
            return Bundle.main.path(forResource: "ru", ofType: "lproj").flatMap(Bundle.init(path:))
        }
    }

    var locale: Locale? {
        switch self {
        case .system: return nil
        case .english: return Locale(identifier: "en")
        case .russian: return Locale(identifier: "ru")
        }
    }
}
