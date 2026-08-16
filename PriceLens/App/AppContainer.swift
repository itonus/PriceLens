import Foundation

/// Explicit dependency container. Tests construct their own with fake providers.
@Observable
@MainActor
final class AppContainer {
    let config: AppConfig
    let launchContext: LaunchContext
    let settings: AppSettings
    let persistenceController: PersistenceController
    let historyRepository: HistoryRepository
    let recognition: RecognitionService
    let searchCoordinator: SearchCoordinator

    /// Chosen scanner: fixture in UI tests / DEBUG demo, live VisionKit otherwise.
    let scanner: any ScannerProvider

    #if DEBUG
    var useFixtureData: Bool {
        didSet { UserDefaults.standard.set(useFixtureData, forKey: "debug.useFixtureData") }
    }
    #endif

    init(launchContext: LaunchContext = .live, config: AppConfig = .default) {
        self.config = config
        self.launchContext = launchContext
        self.settings = AppSettings()
        self.persistenceController = PersistenceController(inMemory: launchContext.isUITestMode)
        self.historyRepository = HistoryRepository(context: persistenceController.container.mainContext,
                                                   limit: config.historyLimit)
        self.recognition = RecognitionService(config: config)

        #if DEBUG
        let storedFixtureFlag = UserDefaults.standard.bool(forKey: "debug.useFixtureData")
        self.useFixtureData = storedFixtureFlag
        let useFixtures = launchContext.isUITestMode || storedFixtureFlag
        #else
        let useFixtures = false
        #endif

        if useFixtures {
            let scenario = launchContext.fixtureScenario ?? .successfulScan
            self.scanner = FixtureScannerProvider(scenario: scenario)
            self.searchCoordinator = SearchCoordinator(
                config: config,
                providers: [FixtureSearchProvider(id: .google, scenario: scenario),
                            FixtureSearchProvider(id: .allegro, scenario: scenario)]
            )
        } else {
            self.scanner = LiveScannerProvider(config: config)
            self.searchCoordinator = SearchCoordinator(
                config: config,
                providers: [GoogleWebSearchProvider(config: config),
                            AllegroWebSearchProvider(config: config)]
            )
        }
    }
}
