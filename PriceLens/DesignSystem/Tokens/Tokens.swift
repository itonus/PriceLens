import SwiftUI

/// Semantic tokens only — no brand palette that could break dark mode.
enum Tokens {
    enum Corner {
        static let control: CGFloat = 22
        static let card: CGFloat = 16
        static let chip: CGFloat = 10
        static let thumbnail: CGFloat = 10
    }

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Hit {
        static let minTarget: CGFloat = 44
    }
}
