import SwiftUI

/// Remote product image. Uses native AsyncImage — no third-party image dependency.
///
/// Provider image URLs are unreliable by nature, so a failure must never destabilize the card:
/// the placeholder keeps the exact same footprint as a loaded image, and the view is hidden
/// from accessibility (the title and price carry the meaning).
struct OfferThumbnail: View {
    let url: URL
    var size: CGFloat = 64

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            case .empty:
                ProgressView().controlSize(.small)
            case .failure:
                Image(systemName: "photo")
                    .foregroundStyle(.tertiary)
            @unknown default:
                Color.clear
            }
        }
        .frame(width: size, height: size)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Tokens.Corner.thumbnail))
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Corner.thumbnail))
        .accessibilityHidden(true)
    }
}
