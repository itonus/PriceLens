import SwiftUI

#if DEBUG
/// DEBUG-only provider diagnostics: runs a live probe search and shows safe metadata
/// (state, strategy, counts, elapsed). Never shows raw HTML. Never compiled in Release.
struct ProviderDiagnosticsView: View {
    @Environment(AppContainer.self) private var container

    @State private var results: [ProviderSearchResult] = []
    @State private var isRunning = false

    var body: some View {
        List {
            ForEach(results, id: \.provider) { result in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(result.provider.displayName).font(.headline)
                        Spacer()
                        Text(result.state.rawValue).foregroundStyle(.secondary)
                    }
                    Text(result.searchURL.absoluteString)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    if let summary = result.debugSummary {
                        Text(summary).font(.caption)
                    }
                    Text("offers: \(result.offers.count) · \(result.duration.formatted(.units(width: .abbreviated)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Provider diagnostics")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isRunning ? "Running…" : "Run probe") { runProbe() }
                    .disabled(isRunning)
            }
        }
    }

    private func runProbe() {
        isRunning = true
        results = []
        let identity = ProductIdentity(barcode: "5901234123457", brand: "Sony", model: "WH-1000XM6",
                                       titleHint: nil, rawRecognizedText: [],
                                       query: "Sony WH-1000XM6")
        let request = ProductSearchRequest(identity: identity, query: identity.query,
                                           countryCode: "PL", currencyCode: "PLN",
                                           preferredLanguage: "pl")
        Task {
            let google = GoogleWebSearchProvider()
            let allegro = AllegroWebSearchProvider()
            async let g = google.search(request)
            async let a = allegro.search(request)
            let (gr, ar) = await (g, a)
            await MainActor.run {
                results = [gr, ar]
                isRunning = false
            }
        }
    }
}
#endif
