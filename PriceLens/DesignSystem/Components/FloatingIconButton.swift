import SwiftUI

/// Compact circular glass button for camera chrome (history / torch / settings).
struct FloatingIconButton: View {
    let systemImage: String
    let label: String
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isActive ? Color.yellow : .white)
                .frame(width: Tokens.Hit.minTarget, height: Tokens.Hit.minTarget)
                .contentShape(Circle())
                .glassControlBackground(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
    }
}
