import Foundation
import VisionKit
import Vision
import UIKit
import AVFoundation

/// Live scanner backed by VisionKit DataScannerViewController.
@MainActor
final class LiveScannerProvider: NSObject, ScannerProvider {
    private let config: AppConfig
    private(set) var dataScanner: DataScannerViewController?

    private var continuation: AsyncStream<ScannerEvent>.Continuation?
    private(set) lazy var eventStream: AsyncStream<ScannerEvent> = AsyncStream { [weak self] continuation in
        self?.continuation = continuation
    }
    var events: AsyncStream<ScannerEvent> { eventStream }

    /// Tracks UUID ↔ stable identity of recognized items across frames.
    private var seenItems: [UUID: (kind: ScannerItemKind, firstSeen: ContinuousClock.Instant)] = [:]

    init(config: AppConfig = .default) {
        self.config = config
        super.init()
    }

    static var isSupported: Bool { DataScannerViewController.isSupported }
    static var isAvailable: Bool { DataScannerViewController.isAvailable }

    static var authorizationStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    static func requestAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    /// DataScannerViewController exposes no public torch API. `AVCaptureDevice.default(for:)`
    /// can return a virtual multi-camera device on Pro models, which is a different object than
    /// the physical wide-angle camera DataScannerViewController actually drives internally —
    /// locking configuration on that mismatched device is what caused the previous freeze.
    /// Targeting the same physical `.builtInWideAngleCamera` device VisionKit uses avoids that.
    private static var torchDevice: AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }

    var isTorchAvailable: Bool {
        Self.torchDevice?.hasTorch ?? false
    }

    func makeDataScanner() -> DataScannerViewController {
        if let existing = dataScanner { return existing }
        let scanner = DataScannerViewController(
            recognizedDataTypes: [
                .barcode(symbologies: [
                    .ean13, .ean8, .upce, .code128, .code39, .code93, .qr, .dataMatrix, .aztec, .pdf417
                ]),
                .text(languages: config.ocrLanguages, textContentType: .currency)
            ],
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: true,
            isGuidanceEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = self
        dataScanner = scanner
        return scanner
    }

    func start() async throws {
        guard Self.isSupported else { throw ScannerError.unsupported }
        guard Self.isAvailable else { throw ScannerError.unavailable }
        let scanner = makeDataScanner()
        do {
            try scanner.startScanning()
        } catch {
            Log.scanner.error("startScanning failed: \(error.localizedDescription)")
            throw ScannerError.unavailable
        }
    }

    func stop() {
        dataScanner?.stopScanning()
        setTorchEnabled(false)
        seenItems.removeAll()
    }

    func setTorchEnabled(_ enabled: Bool) {
        guard let device = Self.torchDevice, device.hasTorch else { return }
        // lockForConfiguration()/unlockForConfiguration() are synchronous IPC calls to the
        // camera daemon and can briefly block; running them on the main actor while
        // DataScannerViewController's capture session is active froze the whole scanner UI.
        // AVCaptureDevice's configuration APIs are documented as callable from any thread,
        // so this cross-actor hop is safe despite AVCaptureDevice not being Sendable.
        nonisolated(unsafe) let unsafeDevice = device
        Task.detached(priority: .userInitiated) {
            do {
                try unsafeDevice.lockForConfiguration()
                unsafeDevice.torchMode = enabled ? .on : .off
                unsafeDevice.unlockForConfiguration()
            } catch {
                Log.scanner.error("Torch toggle failed: \(error.localizedDescription)")
            }
        }
    }

    func capturePhoto() async throws -> UIImage {
        guard let scanner = dataScanner else { throw ScannerError.unavailable }
        do {
            return try await scanner.capturePhoto()
        } catch {
            Log.scanner.error("capturePhoto failed: \(error.localizedDescription)")
            throw ScannerError.captureFailed
        }
    }

    // MARK: - Item mapping

    nonisolated private static func rect(for b: RecognizedItem.Bounds) -> CGRect {
        let minX = min(b.topLeft.x, b.topRight.x, b.bottomLeft.x, b.bottomRight.x)
        let minY = min(b.topLeft.y, b.topRight.y, b.bottomLeft.y, b.bottomRight.y)
        let maxX = max(b.topLeft.x, b.topRight.x, b.bottomLeft.x, b.bottomRight.x)
        let maxY = max(b.topLeft.y, b.topRight.y, b.bottomLeft.y, b.bottomRight.y)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    nonisolated private static func kind(for item: RecognizedItem) -> ScannerItemKind? {
        switch item {
        case .barcode(let barcode):
            guard let payload = barcode.payloadStringValue, !payload.isEmpty else { return nil }
            return .barcode(value: payload, symbology: barcode.observation.symbology.rawValue)
        case .text(let text):
            let value = text.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return nil }
            if let money = PriceParser.parse(value) {
                return .price(money)
            }
            return .text(value: value)
        @unknown default:
            return nil
        }
    }
}

// MARK: - DataScannerViewControllerDelegate

/// Sendable snapshot of a recognized item, extracted on the delegate thread.
private struct ItemSnapshot: Sendable {
    let id: UUID
    let kind: ScannerItemKind
    let bounds: CGRect
}

extension LiveScannerProvider: DataScannerViewControllerDelegate {
    nonisolated private static func snapshot(_ item: RecognizedItem) -> ItemSnapshot? {
        guard let kind = kind(for: item) else { return nil }
        return ItemSnapshot(id: item.id, kind: kind, bounds: rect(for: item.bounds))
    }

    nonisolated func dataScanner(_ dataScanner: DataScannerViewController,
                                 didAdd addedItems: [RecognizedItem],
                                 allItems: [RecognizedItem]) {
        let snapshots = allItems.compactMap(Self.snapshot)
        Task { @MainActor in self.replaceAll(with: snapshots) }
    }

    nonisolated func dataScanner(_ dataScanner: DataScannerViewController,
                                 didUpdate updatedItems: [RecognizedItem],
                                 allItems: [RecognizedItem]) {
        let snapshots = allItems.compactMap(Self.snapshot)
        Task { @MainActor in self.replaceAll(with: snapshots) }
    }

    nonisolated func dataScanner(_ dataScanner: DataScannerViewController,
                                 didRemove removedItems: [RecognizedItem],
                                 allItems: [RecognizedItem]) {
        let snapshots = allItems.compactMap(Self.snapshot)
        Task { @MainActor in self.replaceAll(with: snapshots) }
    }

    nonisolated func dataScanner(_ dataScanner: DataScannerViewController,
                                 becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
        Task { @MainActor in self.continuation?.yield(.availabilityChanged(false)) }
    }

    /// Rebuilds the full observation set from allItems (single source of truth per frame).
    private func replaceAll(with snapshots: [ItemSnapshot]) {
        let now = ContinuousClock.now
        var next: [UUID: (kind: ScannerItemKind, firstSeen: ContinuousClock.Instant)] = [:]
        var observations: [ScannerObservation] = []
        observations.reserveCapacity(snapshots.count)

        for item in snapshots {
            let firstSeen = seenItems[item.id]?.firstSeen ?? now
            next[item.id] = (item.kind, firstSeen)
            observations.append(ScannerObservation(
                id: item.id,
                kind: item.kind,
                bounds: item.bounds,
                firstSeen: firstSeen,
                lastSeen: now
            ))
        }
        seenItems = next
        continuation?.yield(.observations(observations))
    }
}
