import SwiftUI
import Observation

enum AppTab: Int, CaseIterable {
    case home, capture, quiz, schedule, graph

    var label: String {
        switch self {
        case .home:     return "Home"
        case .capture:  return "Capture"
        case .quiz:     return "Quiz"
        case .schedule: return "Schedule"
        case .graph:    return "Graph"
        }
    }

    var icon: String {
        switch self {
        case .home:     return "house.fill"
        case .capture:  return "camera.fill"
        case .quiz:     return "waveform"
        case .schedule: return "calendar"
        case .graph:    return "circle.hexagongrid.fill"
        }
    }
}

@Observable
final class AppState {
    var isOnboarded: Bool
    var selectedTab: AppTab = .home
    var quizSubject: Subject?
    var showQuiz: Bool = false
    var quizStreak: Int
    var sessionsToday: Int

    private let lastSessionDateKey = "bc_last_session_date"

    init() {
        self.isOnboarded = UserDefaults.standard.bool(forKey: "bc_onboarded")
        self.quizStreak = UserDefaults.standard.integer(forKey: "bc_streak")
        self.sessionsToday = UserDefaults.standard.integer(forKey: "bc_sessions_today")

        // Reset sessionsToday if it's a new day
        checkMidnightReset()
    }

    private func checkMidnightReset() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastDateRaw = UserDefaults.standard.string(forKey: lastSessionDateKey)
        if let lastDateStr = lastDateRaw,
           let lastDate = ISO8601DateFormatter().date(from: lastDateStr) {
            let lastDay = calendar.startOfDay(for: lastDate)
            if lastDay < today {
                // New day — reset sessions
                sessionsToday = 0
                UserDefaults.standard.set(sessionsToday, forKey: "bc_sessions_today")
                // If more than 1 day passed, break the streak
                let daysBetween = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
                if daysBetween > 1 {
                    quizStreak = 0
                    UserDefaults.standard.set(quizStreak, forKey: "bc_streak")
                }
            }
        }
        // Update last session date
        UserDefaults.standard.set(ISO8601DateFormatter().string(from: today), forKey: lastSessionDateKey)
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "bc_onboarded")
        isOnboarded = true
    }

    func recordSession() {
        checkMidnightReset()
        sessionsToday += 1
        quizStreak += 1
        UserDefaults.standard.set(sessionsToday, forKey: "bc_sessions_today")
        UserDefaults.standard.set(quizStreak, forKey: "bc_streak")
    }

    func startQuiz(for subject: Subject) {
        quizSubject = subject
        showQuiz = true
        selectedTab = .quiz
    }
}
