import Foundation
import SwiftData

@MainActor
final class PersistenceController {
    let container: ModelContainer

    init(inMemory: Bool = false) {
        let schema = Schema([ScanHistoryRecord.self, SearchCacheRecord.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Release-blocking: a launch crash here is unacceptable. Fall back to in-memory
            // and log loudly rather than crashing the app.
            Log.persistence.error("SwiftData container failed: \(error.localizedDescription). Falling back to in-memory store.")
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                container = try ModelContainer(for: schema, configurations: [fallback])
            } catch {
                fatalError("SwiftData in-memory fallback failed: \(error)")
            }
        }
    }

    static let preview = PersistenceController(inMemory: true)
}
