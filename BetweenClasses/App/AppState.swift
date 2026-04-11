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
    var quizTopicName: String?
    var quizNoteIDs: [UUID] = []
    var showQuiz: Bool = false
    var quizStreak: Int
    var sessionsToday: Int

    init() {
        self.isOnboarded = UserDefaults.standard.bool(forKey: "bc_onboarded")
        self.quizStreak = UserDefaults.standard.integer(forKey: "bc_streak")
        self.sessionsToday = UserDefaults.standard.integer(forKey: "bc_sessions_today")
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "bc_onboarded")
        isOnboarded = true
    }

    func recordSession() {
        sessionsToday += 1
        UserDefaults.standard.set(sessionsToday, forKey: "bc_sessions_today")
    }

    func startQuiz(for subject: Subject, topicName: String? = nil, noteIDs: [UUID] = []) {
        quizSubject = subject
        quizTopicName = topicName
        quizNoteIDs = noteIDs
        showQuiz = true
        selectedTab = .quiz
    }

    func clearQuizSelection() {
        quizSubject = nil
        quizTopicName = nil
        quizNoteIDs = []
        showQuiz = false
    }
}

