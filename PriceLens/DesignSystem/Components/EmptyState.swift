import SwiftUI

/// Simple native empty state: symbol, title, optional message.
struct EmptyState: View {
    let systemImage: String
    let title: String
    var message: String? = nil

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            if let message {
                Text(message)
            }
        }
    }
}
