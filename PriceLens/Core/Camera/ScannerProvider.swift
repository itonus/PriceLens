import CoreGraphics
import Foundation
import UIKit

enum ScannerItemKind: Sendable, Hashable {
    case barcode(value: String, symbology: String)
    case text(value: String)
    case price(Money)
}

/// One recognized item in the live camera view. Bounds are in scanner-view coordinates.
struct ScannerObservation: Sendable, Identifiable, Hashable {
    let id: UUID
    let kind: ScannerItemKind
    let bounds: CGRect
    var firstSeen: ContinuousClock.Instant
    var lastSeen: ContinuousClock.Instant

    static func == (lhs: ScannerObservation, rhs: ScannerObservation) -> Bool {
        lhs.id == rhs.id && lhs.kind == rhs.kind && lhs.bounds == rhs.bounds && lhs.firstSeen == rhs.firstSeen
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id); hasher.combine(kind); hasher.combine(bounds); hasher.combine(firstSeen)
    }
}

enum ScannerEvent: Sendable {
    /// Full set of currently visible recognized items.
    case observations([ScannerObservation])
    case availabilityChanged(Bool)
}

enum ScannerError: Error, Sendable {
    case unsupported
    case unavailable
    case permissionDenied
    case captureFailed
}

/// Live or fixture scanner. The scanner is testable without a camera by
/// injecting a deterministic implementation.
@MainActor
protocol ScannerProvider: AnyObject {
    var events: AsyncStream<ScannerEvent> { get }
    var isTorchAvailable: Bool { get }
    func start() async throws
    func stop()
    func setTorchEnabled(_ enabled: Bool)
    func capturePhoto() async throws -> UIImage
}

extension ScannerProvider {
    var isTorchAvailable: Bool { false }
    func setTorchEnabled(_ enabled: Bool) {}
}
