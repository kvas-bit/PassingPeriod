import SwiftUI
import UIKit

extension Color {
    // Backgrounds
    static let bgPrimary  = Color(hex: "#08090a")
    static let bgSurface  = Color(hex: "#0f1011")
    static let bgElevated = Color(hex: "#191a1b")

    // Text
    static let textPrimary = Color.white
    static let textSecond  = Color.white.opacity(0.5)
    static let textTertiary = Color.white.opacity(0.25)

    // Glass
    static let glassStroke = Color.white.opacity(0.08)
    static let glassFill   = Color.white.opacity(0.04)

    // Accent (monochrome — white fills on dark)
    static let accentPrimary = Color.white

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >>  8) & 0xFF) / 255
            b = Double( int        & 0xFF) / 255
        default:
            r = 1; g = 1; b = 1
        }
        self.init(red: r, green: g, blue: b)
    }

    /// For SceneKit / UIKit bridges (e.g. knowledge graph nodes).
    var uiColor: UIColor { UIColor(self) }
}
