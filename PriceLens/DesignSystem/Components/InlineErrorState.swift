import SwiftUI

/// Inline (non-modal) error/fallback row used inside the results sheet.
/// Never blocks scanning; offers retry and/or direct provider link.
struct InlineErrorState: View {
    let message: String
    var openTitle: String? = nil
    var onOpen: (() -> Void)? = nil
    var retryTitle: String? = nil
    var onRetry: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: Tokens.Spacing.s) {
                if let openTitle, let onOpen {
                    Button(openTitle, action: onOpen)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
                if let retryTitle, let onRetry {
                    Button(retryTitle, action: onRetry)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
        .padding(Tokens.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Tokens.Corner.card))
        .accessibilityElement(children: .contain)
    }
}
