import SwiftUI

/// Small chip showing one provider's live status: searching / N offers / open fallback.
struct ProviderStatusChip: View {
    let provider: SearchProviderID
    let state: ProviderSearchState?
    var offerCount: Int = 0
    var isSearching: Bool = false

    @Environment(AppSettings.self) private var settings

    private var text: String {
        if isSearching { return "\(provider.displayName)…" }
        guard let state else { return provider.displayName }
        switch state {
        case .success: return "\(provider.displayName): \(offerCount)"
        case .partial: return "\(provider.displayName): \(offerCount)*"
        case .fallbackOnly, .blocked, .failed, .offline: return provider.displayName
        }
    }

    private var icon: String {
        if isSearching { return "magnifyingglass" }
        switch state {
        case .success: return "checkmark"
        case .partial: return "exclamationmark"
        case .fallbackOnly, .blocked, .failed: return "arrow.up.forward"
        case .offline: return "wifi.slash"
        case nil: return "magnifyingglass"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            if isSearching {
                ProgressView().controlSize(.mini)
            } else {
                Image(systemName: icon).font(.caption2.weight(.bold))
            }
            Text(text)
                .font(.caption.weight(.medium))
                .contentTransition(.numericText())
        }
        .padding(.horizontal, Tokens.Spacing.xs)
        .padding(.vertical, Tokens.Spacing.xxs)
        .background(.quaternary, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}
