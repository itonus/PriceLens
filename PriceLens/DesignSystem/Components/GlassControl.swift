import SwiftUI

/// Liquid Glass on iOS 26+, system material fallback on iOS 18-25.
/// Use for floating controls over the camera — not for content cards.
struct GlassControl<S: Shape>: View {
    let shape: S

    init(shape: S = Capsule()) {
        self.shape = shape
    }

    var body: some View {
        if #available(iOS 26, *) {
            shape.fill(.clear).glassEffect(.regular, in: shape)
        } else {
            shape.fill(.ultraThinMaterial)
        }
    }
}

extension View {
    /// Applies the floating-control glass/material background to any content.
    func glassControlBackground<S: Shape>(_ shape: S) -> some View {
        background(GlassControl(shape: shape))
    }
}
