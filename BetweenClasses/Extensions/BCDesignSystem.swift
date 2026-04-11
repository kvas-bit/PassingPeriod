import SwiftUI

/// Shared layout and motion tokens for a consistent monochrome glass UI.
enum BCSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let gutter: CGFloat = 20
}

enum BCRadius {
    static let chip: CGFloat = 100
    static let control: CGFloat = 12
    static let card: CGFloat = 16
    static let panel: CGFloat = 20
    static let dock: CGFloat = 28
}

enum BCMotion {
    static let panelSpring = Animation.spring(response: 0.42, dampingFraction: 0.78)
    static let microSpring = Animation.spring(response: 0.24, dampingFraction: 0.72)
    static let gentleEase = Animation.easeInOut(duration: 0.22)
}
