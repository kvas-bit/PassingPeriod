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
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.textSecond)
                    .textCase(.uppercase)
                    .tracking(1.15)
                Spacer()
                trailing()
            }
            .padding(.horizontal, BCSpacing.xl)
            .padding(.top, BCSpacing.md)
            .padding(.bottom, BCSpacing.sm)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.bcAccent.opacity(0.55), Color.bcAccent.opacity(0.08)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
                .padding(.horizontal, BCSpacing.xl)
                .padding(.bottom, BCSpacing.sm)
        }
        .background {
            RoundedRectangle(cornerRadius: BCRadius.panel, style: .continuous)
                .fill(.ultraThinMaterial)
                .background {
                    RoundedRectangle(cornerRadius: BCRadius.panel, style: .continuous)
                        .fill(Color.bgSurface.opacity(0.72))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: BCRadius.panel, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.14), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
        }
        .shadow(color: BCShadow.chrome.color, radius: BCShadow.chrome.radius, x: 0, y: BCShadow.chrome.y)
    }
}
