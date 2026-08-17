import Foundation

/// Parsed launch arguments (UI tests / DEBUG fixtures).
struct LaunchContext: Sendable {
    let isUITestMode: Bool
    let fixtureScenario: FixtureScenario?

    init(arguments: [String]) {
        isUITestMode = arguments.contains("-UITestMode")
        if let index = arguments.firstIndex(of: "-FixtureScenario"),
           arguments.indices.contains(index + 1) {
            fixtureScenario = FixtureScenario(rawValue: arguments[index + 1])
        } else {
            fixtureScenario = nil
        }
    }

    static let live = LaunchContext(arguments: [])
}

enum FixtureScenario: String, Sendable, CaseIterable {
    case successfulScan
    case noStorePrice
    case providerFailure
    case offline
}

/// Root-level routes presented above the scanner (and above the result sheet).
enum AppRoute: String, Identifiable {
    case history
    case settings

    var id: String { rawValue }
}
