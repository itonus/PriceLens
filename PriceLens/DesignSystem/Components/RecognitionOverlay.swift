import SwiftUI

/// Animated highlight over a recognized barcode/text/price in the camera view.
/// States: detected (thin outline), candidate (stronger + label), locked (success pulse).
struct RecognitionOverlay: View {
    enum Style {
        case detected
        case candidate
        case locked
    }

    let observation: ScannerObservation
    let style: Style
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private var strokeColor: Color {
        switch style {
        case .detected: return .white.opacity(0.85)
        case .candidate: return .white
        case .locked: return .green
        }
    }

    private var lineWidth: CGFloat {
        switch style {
        case .detected: return 1.5
        case .candidate: return 2.5
        case .locked: return 3
        }
    }

    var body: some View {
        Button(action: onTap) {
            RoundedRectangle(cornerRadius: 10)
                .stroke(strokeColor, lineWidth: lineWidth)
                .shadow(color: .black.opacity(0.4), radius: 2)
                .frame(width: max(observation.bounds.width + 12, 24),
                       height: max(observation.bounds.height + 12, 24))
                .overlay(alignment: .topLeading) {
                    label
                        .offset(y: -4)
                        .alignmentGuide(.top) { $0[.bottom] }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .position(x: observation.bounds.midX, y: observation.bounds.midY)
        .scaleEffect(style == .locked && !reduceMotion ? (pulse ? 1.05 : 1.0) : 1.0)
        .animation(reduceMotion ? .none : .spring(duration: 0.25), value: style)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint(Text("Double-tap to select"))
    }

    @ViewBuilder
    private var label: some View {
        switch (style, observation.kind) {
        case (.detected, _):
            EmptyView()
        case (_, .barcode(let value, _)):
            chip(text: value)
        case (_, .price(let money)):
            chip(text: MoneyFormatter.string(money))
        case (_, .text(let value)):
            chip(text: String(value.prefix(28)))
        }
    }

    private func chip(text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, Tokens.Spacing.xs)
            .padding(.vertical, Tokens.Spacing.xxs)
            .background(.black.opacity(0.65), in: Capsule())
    }

    private var accessibilityText: String {
        switch observation.kind {
        case .barcode(let value, _): return "Barcode \(value)"
        case .price(let money): return "Price \(MoneyFormatter.string(money))"
        case .text(let value): return value
        }
    }
}
