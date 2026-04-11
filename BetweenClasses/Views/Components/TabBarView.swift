import SwiftUI

struct TabBarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                TabBarItem(
                    tab: tab,
                    isSelected: appState.selectedTab == tab
                ) {
                    appState.selectedTab = tab
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: BCRadius.dock, style: .continuous)
                .fill(.ultraThinMaterial)
                .background {
                    RoundedRectangle(cornerRadius: BCRadius.dock, style: .continuous)
                        .fill(Color.bgElevated.opacity(0.88))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: BCRadius.dock, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.16),
                                    Color.white.opacity(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: Color.black.opacity(0.55), radius: 28, x: 0, y: 14)
        }
        .padding(.horizontal, BCSpacing.lg)
        .padding(.bottom, 10)
    }
}

private struct TabBarItem: View {
    let tab: AppTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    // Pill glow behind selected icon
                    if isSelected {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 44, height: 28)
                            .blur(radius: 4)
                    }

                    Image(systemName: tab.icon)
                        .font(.system(size: 19, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.4))
                        .scaleEffect(isSelected ? 1.05 : 1.0)
                }
                .frame(height: 28)

                Text(tab.label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.4))
                    .tracking(0.2)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(BCMotion.microSpring, value: isSelected)
        .accessibilityLabel(tab.label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        Color.bgPrimary.ignoresSafeArea()
        TabBarView()
            .environment(AppState())
    }
}
