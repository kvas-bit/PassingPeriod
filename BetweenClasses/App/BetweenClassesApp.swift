import SwiftUI
import SwiftData

@main
struct BetweenClassesApp: App {
    @State private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: Note.self, Subject.self, QuizSession.self, QuizQuestion.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

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
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active || newPhase == .background else { return }
                LiveActivitySyncService.shared.sync(using: modelContainer.mainContext)
            }
            .task {
                LiveActivitySyncService.shared.sync(using: modelContainer.mainContext)
            }
        }
        .modelContainer(modelContainer)
    }
}
