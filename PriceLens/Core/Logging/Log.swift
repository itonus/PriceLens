import Foundation
import OSLog

enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.itonus.PriceLens"

    static let scanner = Logger(subsystem: subsystem, category: "scanner")
    static let recognition = Logger(subsystem: subsystem, category: "recognition")
    static let google = Logger(subsystem: subsystem, category: "search.google")
    static let allegro = Logger(subsystem: subsystem, category: "search.allegro")
    static let matching = Logger(subsystem: subsystem, category: "matching")
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let app = Logger(subsystem: subsystem, category: "app")
}
