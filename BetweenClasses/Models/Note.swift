import SwiftData
import Foundation

@Model
final class Note {
    var id: UUID
    var imageData: Data?
    var extractedText: String
    var subjectID: UUID
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var questions: [QuizQuestion]

    init(imageData: Data? = nil, extractedText: String, subjectID: UUID) {
        self.id = UUID()
        self.imageData = imageData
        self.extractedText = extractedText
        self.subjectID = subjectID
        self.createdAt = Date()
        self.questions = []
    }
}
