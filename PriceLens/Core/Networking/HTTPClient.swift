import Foundation

enum HTTPError: Error, Sendable {
    case badStatus(Int)
    case invalidResponse
    case offline
}

/// Thin URLSession wrapper. HTTPS enforced by ATS; per-provider timeout from AppConfig.
struct HTTPClient: Sendable {
    let config: AppConfig

    private let session: URLSession

    init(config: AppConfig = .default, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    /// Fetches a page. Never retries aggressively: one attempt per call.
    func get(_ url: URL, acceptLanguage: String = "pl-PL,pl;q=0.9,en;q=0.8") async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url, timeoutInterval: config.providerTimeout)
        request.setValue(config.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(acceptLanguage, forHTTPHeaderField: "Accept-Language")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw HTTPError.invalidResponse }
            return (data, http)
        } catch let error as URLError where error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
            throw HTTPError.offline
        }
    }
}
