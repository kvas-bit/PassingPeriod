import SwiftUI

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        // Inner gradient for depth — top-left lighter, bottom-right darker
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.07),
                                        Color.white.opacity(0.01)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                Color.white.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
            }
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20) -> some View {
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
