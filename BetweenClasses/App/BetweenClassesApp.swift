import SwiftUI
import SwiftData

@main
struct BetweenClassesApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isOnboarded {
                    ContentRootView()
                } else {
                    OnboardingView()
                }
            }
            .environment(appState)
            .preferredColorScheme(.dark)
        }
        .modelContainer(for: [Note.self, Subject.self, QuizSession.self, QuizQuestion.self])
    }
}
