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
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.055),
                                        Color.white.opacity(0.012)
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
                                Color.white.opacity(0.22),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: Color.black.opacity(0.45), radius: 20, x: 0, y: 10)
            .shadow(color: Color.white.opacity(0.04), radius: 1, x: 0, y: -0.5)
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
    /// Headline: 22pt semibold, tracking -0.8
    static let bcHeadline = Font.system(size: 22, weight: .semibold, design: .default)
    /// Body: 16pt regular, tracking -0.3
    static let bcBody = Font.system(size: 16, weight: .regular, design: .default)
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
    func bcCaption() -> some View {
        self.font(.bcCaption).tracking(0.5)
    }
}
