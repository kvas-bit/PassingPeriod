import SwiftData
import Foundation

@Model
final class QuizSession {
    var id: UUID
    var subjectID: UUID
    var startedAt: Date
    var score: Int
    var totalQuestions: Int
    @Relationship(deleteRule: .cascade) var questions: [QuizQuestion]

    init(subjectID: UUID) {
        self.id = UUID()
        self.subjectID = subjectID
        self.startedAt = Date()
        self.score = 0
        self.totalQuestions = 0
        self.questions = []
    }

    var percentage: Double {
        guard totalQuestions > 0 else { return 0 }
        return Double(score) / Double(totalQuestions)
    }
}
