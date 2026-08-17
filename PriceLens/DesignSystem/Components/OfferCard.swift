import SwiftUI

/// One normalized offer. Item price dominant; total shown only when calculable.
struct OfferCard: View {
    let offer: Offer
    let onOpen: () -> Void

    @Environment(AppSettings.self) private var settings

    private var matchBadgeText: String {
        switch offer.matchConfidence {
        case .exact: return settings.localized("match.exact")
        case .high: return settings.localized("match.high")
        case .medium, .low: return settings.localized("match.possible")
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Spacing.s) {
            if let imageURL = offer.imageURL {
                OfferThumbnail(url: imageURL)
            }
            details
        }
        .padding(Tokens.Spacing.s)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Tokens.Corner.card))
        .accessibilityElement(children: .contain)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
            HStack {
                Text(offer.provider.displayName)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, Tokens.Spacing.xs)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
                Spacer()
                Text(matchBadgeText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(offer.matchConfidence >= .high ? Color.green : .secondary)
            }

            Text(offer.title)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)

            HStack(alignment: .firstTextBaseline) {
                Text(MoneyFormatter.string(offer.itemPrice, locale: settings.activeLocale))
                    .font(.title3.weight(.bold))
                Spacer()
                Button(action: onOpen) {
                    Text(settings.localized("offer.open"))
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("\(settings.localized("offer.open")) \(offer.provider.displayName)")
            }

            if let total = offer.totalPrice {
                Text(totalText(total))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(settings.localized("offer.deliveryUnknown"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let seller = offer.seller {
                Text(seller)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func totalText(_ total: Money) -> String {
        let delivery = offer.deliveryPrice.map { MoneyFormatter.string($0, locale: settings.activeLocale) } ?? "?"
        let totalString = MoneyFormatter.string(total, locale: settings.activeLocale)
        return String(format: settings.localized("offer.totalFormat"), delivery, totalString)
    }
}
