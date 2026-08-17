import Foundation

/// What a barcode actually identifies, resolved from an open product database.
struct ResolvedProduct: Sendable, Hashable {
    let barcode: String
    let name: String?
    let brand: String?
    let imageURL: URL?

    /// Best display/search phrase: "Brand Name" when both are known.
    var displayTitle: String? {
        switch (brand, name) {
        case let (brand?, name?):
            // Avoid "Haribo Haribo Wummis" when the name already carries the brand.
            if name.localizedCaseInsensitiveContains(brand) { return name }
            return "\(brand) \(name)"
        case let (nil, name?): return name
        case let (brand?, nil): return brand
        default: return nil
        }
    }
}

/// Resolves a scanned barcode into a real product identity.
///
/// Uses Open Food Facts: free, keyless, no backend, on-device. It is an open food database,
/// so non-food barcodes legitimately miss — callers must treat `nil` as "unknown", never as
/// an error, and must not fabricate an identity when lookup fails.
protocol ProductResolving: Sendable {
    func resolve(barcode: String) async -> ResolvedProduct?
}

struct OpenFoodFactsResolver: ProductResolving {
    private let session: URLSession
    private let timeout: TimeInterval

    init(session: URLSession = .shared, timeout: TimeInterval = 6) {
        self.session = session
        self.timeout = timeout
    }

    private struct Response: Decodable {
        struct Product: Decodable {
            let product_name: String?
            let brands: String?
            let image_url: String?
        }
        let status: Int
        let product: Product?
    }

    func resolve(barcode: String) async -> ResolvedProduct? {
        let digits = barcode.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }

        var components = URLComponents(string: "https://world.openfoodfacts.org/api/v2/product/\(digits).json")!
        components.queryItems = [URLQueryItem(name: "fields", value: "product_name,brands,image_url")]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url, timeoutInterval: timeout)
        // Open Food Facts asks API clients to identify themselves.
        request.setValue("PriceLens/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            let decoded = try JSONDecoder().decode(Response.self, from: data)
            guard decoded.status == 1, let product = decoded.product else { return nil }

            let name = product.product_name?.trimmingCharacters(in: .whitespacesAndNewlines)
            // `brands` is a comma-separated list; the first entry is the primary brand.
            let brand = product.brands?
                .split(separator: ",").first
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

            let resolved = ResolvedProduct(
                barcode: digits,
                name: (name?.isEmpty == false) ? name : nil,
                brand: (brand?.isEmpty == false) ? brand : nil,
                imageURL: product.image_url.flatMap(URL.init(string:))
            )
            // A hit with no usable text is the same as no hit.
            return resolved.displayTitle == nil ? nil : resolved
        } catch {
            Log.recognition.debug("Barcode resolve failed: \(error.localizedDescription)")
            return nil
        }
    }
}
