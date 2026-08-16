import Foundation
import WebKit

/// Optional WKWebView rendered loader — third strategy when server HTML lacks content.
/// Rules: one navigation per user search, no challenge bypass, ephemeral store,
/// cancelled when the scan is superseded. Never exposed to feature views.
@MainActor
final class WebPageLoader: NSObject {
    private var webView: WKWebView?
    private var continuation: CheckedContinuation<String, Error>?
    private var timeoutTask: Task<Void, Never>?

    func loadRenderedHTML(_ url: URL, timeout: TimeInterval) async throws -> String {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                self.timeoutTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(timeout))
                    guard !Task.isCancelled else { return }
                    self?.finish(.failure(ScannerError.captureFailed), webView: nil)
                }
                webView.load(URLRequest(url: url))
            }
        } onCancel: { [weak self] in
            Task { @MainActor in self?.cancel() }
        }
    }

    private func cancel() {
        timeoutTask?.cancel()
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView = nil
        let continuation = continuation
        self.continuation = nil
        continuation?.resume(throwing: CancellationError())
    }

    private func finish(_ result: Result<String, Error>, webView: WKWebView?) {
        timeoutTask?.cancel()
        guard let continuation else { return }
        self.continuation = nil
        switch result {
        case .success(let html): continuation.resume(returning: html)
        case .failure(let error): continuation.resume(throwing: error)
        }
    }
}

extension WebPageLoader: WKNavigationDelegate {
    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1500)) // let async content settle
            guard self.webView === webView else { return }
            do {
                let html = try await webView.evaluateJavaScript("document.documentElement.outerHTML") as? String ?? ""
                self.finish(.success(html), webView: webView)
            } catch {
                self.finish(.failure(error), webView: webView)
            }
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in self.finish(.failure(error), webView: webView) }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in self.finish(.failure(error), webView: webView) }
    }
}
