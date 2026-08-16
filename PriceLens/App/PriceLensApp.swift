import SwiftUI
import SwiftData

@main
struct PriceLensApp: App {
    @State private var container: AppContainer

    init() {
        let launchContext = LaunchContext(arguments: ProcessInfo.processInfo.arguments)
        _container = State(initialValue: AppContainer(launchContext: launchContext))
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(container)
                .environment(container.settings)
                .environment(\.locale, container.settings.activeLocale)
                .modelContainer(container.persistenceController.container)
        }
    }
}
