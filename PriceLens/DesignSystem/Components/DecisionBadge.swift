import SwiftUI

/// Recommendation badge: Good price here / Fair price / Better online / Compare carefully.
/// Semantic colors; information never carried by color alone (icon + text).
struct DecisionBadge: View {
    let recommendation: PurchaseRecommendation
    var prominent: Bool = false

    @Environment(AppSettings.self) private var settings

    private var text: String {
        switch recommendation {
        case .goodHere: return settings.localized("decision.goodHere")
        case .fairPrice: return settings.localized("decision.fairPrice")
        case .betterOnline: return settings.localized("decision.betterOnline")
        case .compareCarefully: return settings.localized("decision.compareCarefully")
        }
    }

    private var icon: String {
        switch recommendation {
        case .goodHere: return "checkmark.circle.fill"
        case .fairPrice: return "equal.circle.fill"
        case .betterOnline: return "arrow.down.circle.fill"
        case .compareCarefully: return "exclamationmark.circle.fill"
        }
    }

    private var color: Color {
        switch recommendation {
        case .goodHere: return .green
        case .fairPrice: return .secondary
        case .betterOnline: return .orange
        case .compareCarefully: return .secondary
        }
    }

    var body: some View {
        Label(text, systemImage: icon)
            .font(prominent ? .title3.weight(.bold) : .headline)
            .foregroundStyle(color)
            .accessibilityElement(children: .combine)
    }
}
