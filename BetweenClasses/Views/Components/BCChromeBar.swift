import SwiftUI

/// Floating glass navigation strip (v0 / Grok-style top chrome).
struct BCChromeBar<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    init(title: String, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.bcCaption)
                .foregroundStyle(Color.textSecond)
                .textCase(.uppercase)
                .tracking(1.0)
            Spacer()
            trailing()
        }
        .padding(.horizontal, BCSpacing.xl)
        .padding(.vertical, BCSpacing.md)
        .background {
            RoundedRectangle(cornerRadius: BCRadius.panel, style: .continuous)
                .fill(.ultraThinMaterial)
                .background {
                    RoundedRectangle(cornerRadius: BCRadius.panel, style: .continuous)
                        .fill(Color.bgSurface.opacity(0.65))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: BCRadius.panel, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                }
        }
        .shadow(color: Color.black.opacity(0.35), radius: 16, x: 0, y: 8)
    }
}
