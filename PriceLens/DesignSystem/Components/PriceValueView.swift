import SwiftUI

/// Formatted money value with numeric transition when it changes.
struct PriceValueView: View {
    let money: Money?
    var placeholder: LocalizedStringKey = "—"
    var font: Font = .title.weight(.semibold)

    @Environment(AppSettings.self) private var settings

    var body: some View {
        Group {
            if let money {
                Text(MoneyFormatter.string(money, locale: settings.activeLocale))
                    .contentTransition(.numericText())
            } else {
                Text(placeholder)
                    .foregroundStyle(.secondary)
            }
        }
        .font(font)
        .accessibilityLabel(money.map { MoneyFormatter.string($0, locale: settings.activeLocale) } ?? String(localized: "No price"))
    }
}
