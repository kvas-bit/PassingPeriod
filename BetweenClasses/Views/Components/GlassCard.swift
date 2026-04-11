import SwiftUI

/// Standalone glass card container. Use .glassCard() modifier for inline usage.
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat
    var padding: EdgeInsets
    @ViewBuilder var content: () -> Content

    init(
        cornerRadius: CGFloat = 20,
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

    var body: some View {
        Text(text)
            .bcCaption()
            .foregroundStyle(textColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .glassCard(cornerRadius: 100)
    }
}

/// White pill badge (used for "Free now")
struct WhitePill: View {
    let text: String

    var body: some View {
        Text(text)
            .bcCaption()
            .foregroundStyle(.black)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.white, in: Capsule())
    }
}
