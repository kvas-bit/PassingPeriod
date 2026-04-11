import SwiftData
import Foundation

@Model
final class QuizQuestion {
    var id: UUID
    var question: String
    var expectedAnswer: String
    var userAnswer: String?
    var wasCorrect: Bool?
    var noteID: UUID

    init(question: String, expectedAnswer: String, noteID: UUID) {
        self.id = UUID()
        self.question = question
        self.expectedAnswer = expectedAnswer
        self.noteID = noteID
    }
}
