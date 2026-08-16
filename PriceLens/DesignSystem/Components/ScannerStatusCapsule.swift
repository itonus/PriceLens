import SwiftUI

/// Bottom scanner state capsule: "Point at a product", "Searching Google + Allegro…" etc.
/// A Liquid Glass surface on iOS 26+, material capsule earlier.
struct ScannerStatusCapsule: View {
    let text: String
    var systemImage: String? = nil
    var showsActivity: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Tokens.Spacing.xs) {
            if showsActivity {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
            } else if let systemImage {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
            }
            Text(text)
                .font(.subheadline.weight(.medium))
                .contentTransition(.numericText())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Tokens.Spacing.m)
        .padding(.vertical, Tokens.Spacing.s)
        .glassControlBackground(Capsule())
        .shadow(color: .black.opacity(0.25), radius: 8, y: 2)
        .animation(reduceMotion ? .none : .spring(duration: 0.3), value: text)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
        .accessibilityAddTraits(.updatesFrequently)
    }
}
