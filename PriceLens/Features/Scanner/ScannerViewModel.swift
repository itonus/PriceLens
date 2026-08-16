import Foundation
import SwiftUI

/// Scanner screen state machine. Camera-first: launch → permission → live recognition.
@Observable
@MainActor
final class ScannerViewModel {

    enum PermissionState {
        case checking
        case notDetermined
        case authorized
        case denied
        case restricted
        case unsupported
    }

    enum Status: Equatable {
        case idle
        case pointAtProduct
        case barcodeFound
        case readingLabel
        case tapAProduct
        case locked
        case searching
    }

    private let container: AppContainer
    private var recognition: RecognitionService { container.recognition }
    private var scanner: any ScannerProvider { container.scanner }

    var permissionState: PermissionState = .checking
    var status: Status = .idle
    var observations: [ScannerObservation] = []
    var candidateBarcodes: [String] = []
    var lockedBarcodeValue: String?

    /// Locked session drives the result sheet.
    var session: SearchSession?

    var isTorchOn = false
    var isTorchAvailable: Bool { scanner.isTorchAvailable }
    var showsManualEntry = false

    /// Set by the fixture/live pipeline when a lock happens — used for haptics in the view.
    var lockTrigger = 0

    private var eventsTask: Task<Void, Never>?

    init(container: AppContainer) {
        self.container = container
    }

    var isUsingFixtures: Bool { scanner is FixtureScannerProvider }
    var liveProvider: LiveScannerProvider? { scanner as? LiveScannerProvider }

    // MARK: - Lifecycle

    func onAppear() {
        guard eventsTask == nil else { return }
        if isUsingFixtures {
            permissionState = .authorized
            startScanner()
            return
        }
        Task { await prepareLiveScanner() }
    }

    func onDisappear() {
        stopScanner()
    }

    private func prepareLiveScanner() async {
        guard LiveScannerProvider.isSupported, LiveScannerProvider.isAvailable else {
            permissionState = .unsupported
            return
        }
        switch LiveScannerProvider.authorizationStatus {
        case .authorized:
            permissionState = .authorized
            startScanner()
        case .notDetermined:
            permissionState = .notDetermined
        case .denied:
            permissionState = .denied
        case .restricted:
            permissionState = .restricted
        @unknown default:
            permissionState = .denied
        }
    }

    func requestPermissionAndStart() {
        Task {
            let granted = await LiveScannerProvider.requestAccess()
            permissionState = granted ? .authorized : .denied
            if granted { startScanner() }
        }
    }

    private func startScanner() {
        status = .pointAtProduct
        Task {
            do {
                try await scanner.start()
            } catch {
                Log.scanner.error("Scanner start failed: \(error.localizedDescription)")
                permissionState = .unsupported
                return
            }
            consumeEvents()
        }
    }

    private func consumeEvents() {
        eventsTask?.cancel()
        eventsTask = Task { [weak self] in
            guard let self else { return }
            for await event in scanner.events {
                if Task.isCancelled { return }
                self.handle(event)
            }
        }
    }

    func stopScanner() {
        eventsTask?.cancel()
        eventsTask = nil
        scanner.stop()
    }

    // MARK: - Event handling

    private func handle(_ event: ScannerEvent) {
        switch event {
        case .observations(let newObservations):
            observations = newObservations
            guard session == nil else { return } // locked: freeze processing until rescan
            let result = recognition.process(newObservations)
            candidateBarcodes = result.candidateBarcodes
            if let lock = result.lock {
                lockCandidate(lock)
            } else {
                status = mapStatus(result.status)
            }
        case .availabilityChanged(let available):
            if !available { permissionState = .unsupported }
        }
    }

    private func mapStatus(_ status: RecognitionService.Status) -> Status {
        switch status {
        case .pointAtProduct: return .pointAtProduct
        case .barcodeFound: return .barcodeFound
        case .readingLabel: return .readingLabel
        case .tapAProduct: return .tapAProduct
        }
    }

    // MARK: - Locking

    private func lockCandidate(_ candidate: RecognitionService.ScanCandidate) {
        let session = SearchSession(identity: candidate.identity,
                                    storePrice: candidate.storePrice,
                                    activeQuery: candidate.identity.query.isEmpty
                                        ? (candidate.barcodeValue ?? "")
                                        : candidate.identity.query)
        lockedBarcodeValue = candidate.barcodeValue
        lockTrigger += 1
        status = .locked
        self.session = session
    }

    /// Tap-to-select a recognized item (ambiguity resolution or manual pick).
    func select(observation: ScannerObservation) {
        guard session == nil else { return }
        if let candidate = recognition.lock(observation: observation, in: observations) {
            lockCandidate(candidate)
        }
    }

    /// Manual text search ("Type instead").
    func manualSearch(query: String) {
        let cleaned = TextNormalizer.cleanupForDisplay(query)
        guard !cleaned.isEmpty else { return }
        let identity = ProductIdentity(barcode: nil, brand: nil, model: nil,
                                       titleHint: cleaned, rawRecognizedText: [cleaned],
                                       query: cleaned)
        lockCandidate(RecognitionService.ScanCandidate(identity: identity, storePrice: nil,
                                                       barcodeValue: nil, priceWasAmbiguous: false))
    }

    /// Dismiss results and resume scanning.
    func rescan() {
        session = nil
        lockedBarcodeValue = nil
        candidateBarcodes = []
        recognition.reset()
        status = .pointAtProduct
    }

    func toggleTorch() {
        isTorchOn.toggle()
        scanner.setTorchEnabled(isTorchOn)
    }

    // MARK: - Overlay style mapping

    func overlayStyle(for observation: ScannerObservation) -> RecognitionOverlay.Style {
        guard case .barcode(let value, _) = observation.kind else { return .detected }
        if lockedBarcodeValue == value { return .locked }
        if candidateBarcodes.contains(value) { return .candidate }
        return .detected
    }
}
