import SwiftUI

/// Root: the scanner IS the app. No tab bar, no intermediate home screen.
struct AppRootView: View {
    @Environment(AppContainer.self) private var container
    @Environment(AppSettings.self) private var settings

    var body: some View {
        ScannerView()
            .environment(container)
            .environment(settings)
            .preferredColorScheme(nil) // follow system
    }
}
