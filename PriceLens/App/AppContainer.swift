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
    /// Barcode → real product identity. Nil in UI tests (no network).
    let productResolver: (any ProductResolving)?

    /// Chosen scanner: fixture in UI tests / DEBUG demo, live VisionKit otherwise.
    let scanner: any ScannerProvider

    /// Root-level modal route (history/settings), presented above the result sheet.
    var presentedRoute: AppRoute?

    /// A history rerun request, consumed by the scanner view.
    var rerunRequest: SearchSession?

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
        let persistedCache = PersistedSearchCache(context: persistenceController.container.mainContext)

        #if DEBUG
        let storedFixtureFlag = UserDefaults.standard.bool(forKey: "debug.useFixtureData")
        self.useFixtureData = storedFixtureFlag
        let useFixtures = launchContext.isUITestMode || storedFixtureFlag
        #else
        let useFixtures = false
        #endif

        if useFixtures {
            let scenario = launchContext.fixtureScenario ?? .successfulScan
            self.productResolver = nil
            self.scanner = FixtureScannerProvider(scenario: scenario)
            self.searchCoordinator = SearchCoordinator(
                config: config,
                providers: [FixtureSearchProvider(id: .google, scenario: scenario),
                            FixtureSearchProvider(id: .allegro, scenario: scenario)],
                persistedCache: persistedCache
            )
        } else {
            self.productResolver = OpenFoodFactsResolver()
            self.scanner = LiveScannerProvider(config: config)
            // Ceneo only. Google's shopping surface is JS-gated and Allegro's listing page is
            // behind an anti-bot interstitial (its API additionally requires manual application
            // verification), so neither can return offers. Ceneo serves complete server-rendered
            // listings. Allegro remains reachable as a deep link from the result sheet.
            self.searchCoordinator = SearchCoordinator(
                config: config,
                providers: [CeneoWebSearchProvider(config: config)],
                persistedCache: persistedCache
            )
        }
    }
}
