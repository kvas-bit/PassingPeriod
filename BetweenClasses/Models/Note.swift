import SwiftData
import Foundation

@Model
final class Note {
    var id: UUID
    var imageData: Data?
    var extractedText: String
    var subjectID: UUID
    // Keep this optional so existing SwiftData stores migrate cleanly.
    var topicNameValue: String?
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var questions: [QuizQuestion]

    var topicName: String {
        get { Self.normalizeTopicName(topicNameValue) }
        set { topicNameValue = Self.storageValue(for: newValue) }
    }

    init(imageData: Data? = nil, extractedText: String, subjectID: UUID, topicName: String = "Unsorted") {
        self.id = UUID()
        self.imageData = imageData
        self.extractedText = extractedText
        self.subjectID = subjectID
        self.topicNameValue = Self.storageValue(for: topicName)
        self.createdAt = Date()
        self.questions = []
    }

    private static func normalizeTopicName(_ value: String?) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Unsorted" : trimmed
    }

    private static func storageValue(for value: String) -> String? {
        let normalized = normalizeTopicName(value)
        return normalized == "Unsorted" ? nil : normalized
    }
}
