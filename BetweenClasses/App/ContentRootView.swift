import SwiftUI

struct ContentRootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            Group {
                switch appState.selectedTab {
                case .home:
                    HomeView()
                case .capture:
                    NoteCaptureView()
                case .quiz:
                    VoiceQuizView()
                case .schedule:
                    ScheduleView()
                case .graph:
                    KnowledgeGraphView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(placement: .bottom, spacing: 0) {
            TabBarView()
        }
    }
}
