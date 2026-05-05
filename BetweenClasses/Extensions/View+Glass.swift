import SwiftUI

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .background {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.bgSurface.opacity(0.55))
                    }
                    .overlay {
                        // Specular rim — subtle so body text stays legible
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.065),
                                        Color.bcAccent.opacity(0.04),
                                        Color.white.opacity(0.014)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottom
                                )
                            )
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.26),
                                Color.white.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: BCShadow.card.color, radius: BCShadow.card.radius, x: 0, y: BCShadow.card.y)
            .shadow(color: Color.white.opacity(0.045), radius: 1, x: 0, y: -0.5)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = BCRadius.panel) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Typography helpers

extension Font {
    /// Display: 34pt semibold, tracking -1.5
    static let bcDisplay = Font.system(size: 34, weight: .semibold, design: .default)
    /// Large display for hero moments.
    static let bcDisplayLarge = Font.system(size: 38, weight: .semibold, design: .default)
    /// Headline: 22pt semibold, tracking -0.8
    static let bcHeadline = Font.system(size: 22, weight: .semibold, design: .default)
    /// Secondary headline (card titles).
    static let bcTitle = Font.system(size: 20, weight: .semibold, design: .default)
    /// Body: 16pt regular, tracking -0.3
    static let bcBody = Font.system(size: 16, weight: .regular, design: .default)
    /// Body emphasis.
    static let bcBodyStrong = Font.system(size: 16, weight: .semibold, design: .default)
    /// Caption: 12pt medium, tracking +0.5
    static let bcCaption = Font.system(size: 12, weight: .medium, design: .default)
}

extension View {
    func bcDisplay() -> some View {
        self.font(.bcDisplay).tracking(-1.5)
    }
    func bcHeadline() -> some View {
        self.font(.bcHeadline).tracking(-0.8)
    }
    func bcBody() -> some View {
        self.font(.bcBody).tracking(-0.3)
    }
    func bcBodyStrong() -> some View {
        self.font(.bcBodyStrong).tracking(-0.3)
    }
    func bcCaption() -> some View {
        self.font(.bcCaption).tracking(0.5)
    }
    func bcTitle() -> some View {
        self.font(.bcTitle).tracking(-0.6)
    }
    func bcDisplayLarge() -> some View {
        self.font(.bcDisplayLarge).tracking(-1.6)
    }
}
