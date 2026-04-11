import SwiftData
import Foundation

@Model
final class Note {
    var id: UUID
    var imageData: Data?
    var extractedText: String
    var subjectID: UUID
    var topicName: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var questions: [QuizQuestion]

    init(imageData: Data? = nil, extractedText: String, subjectID: UUID, topicName: String = "Unsorted") {
        self.id = UUID()
        self.imageData = imageData
        self.extractedText = extractedText
        self.subjectID = subjectID
        let trimmedTopic = topicName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.topicName = trimmedTopic.isEmpty ? "Unsorted" : trimmedTopic
        self.createdAt = Date()
        self.questions = []
    }
}
