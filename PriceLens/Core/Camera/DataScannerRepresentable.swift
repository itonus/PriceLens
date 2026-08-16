import SwiftUI
import VisionKit

/// SwiftUI wrapper for VisionKit DataScannerViewController (live mode only).
struct DataScannerRepresentable: UIViewControllerRepresentable {
    let provider: LiveScannerProvider

    func makeUIViewController(context: Context) -> DataScannerViewController {
        provider.makeDataScanner()
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}
}
