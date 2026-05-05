import SwiftUI

/// Standalone glass card container. Use .glassCard() modifier for inline usage.
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat
    var padding: EdgeInsets
    @ViewBuilder var content: () -> Content

    init(
        cornerRadius: CGFloat = BCRadius.panel,
        padding: EdgeInsets = EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20),
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .glassCard(cornerRadius: cornerRadius)
    }
}

/// Small pill-shaped glass chip (used for stats, badges)
struct GlassChip: View {
    let text: String
    var textColor: Color = .textPrimary
    var leadingSymbol: String?
    /// When set, tints the leading SF Symbol; otherwise the symbol uses a softened `textColor`.
    var symbolColor: Color? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let leadingSymbol {
                Image(systemName: leadingSymbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(symbolColor ?? textColor.opacity(0.85))
            }
            Text(text)
                .bcCaption()
                .foregroundStyle(textColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassCard(cornerRadius: BCRadius.chip)
    }
}

/// White pill badge (used for "Free now")
struct WhitePill: View {
    let text: String
    /// `True` for high-emphasis status (e.g. class in session).
    var prominent: Bool = false

    var body: some View {
        Text(text)
            .bcCaption()
            .fontWeight(.semibold)
            .foregroundStyle(prominent ? Color.accentOnAccent : Color.textPrimary)
            .padding(.horizontal, prominent ? 11 : 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(prominent ? Color.bcAccent : Color.white.opacity(0.14))
            )
            .overlay(
                Capsule().strokeBorder(Color.white.opacity(prominent ? 0.2 : 0.12), lineWidth: 1)
            )
    }
}
