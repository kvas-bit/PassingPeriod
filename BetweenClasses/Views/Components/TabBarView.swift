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
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .padding(.bottom, 28)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.glassStroke),
            alignment: .top
        )
    }
}

private struct TabBarItem: View {
    let tab: AppTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.35))

                Text(tab.label)
                    .bcCaption()
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.35))
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        Color.bgPrimary.ignoresSafeArea()
        TabBarView()
            .environment(AppState())
    }
}
