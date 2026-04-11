import SwiftData
import Foundation

@Model
final class Subject {
    var id: UUID
    var name: String
    var instructor: String
    var colorHex: String
    var scheduleJSON: String
    var canvasID: String
    @Relationship(deleteRule: .cascade) var notes: [Note]

    init(name: String, instructor: String = "", colorHex: String = "#FFFFFF", canvasID: String = "") {
        self.id = UUID()
        self.name = name
        self.instructor = instructor
        self.colorHex = colorHex
        self.scheduleJSON = "[]"
        self.canvasID = canvasID
        self.notes = []
    }

    var scheduleTimes: [ClassTime] {
        get {
            guard let data = scheduleJSON.data(using: .utf8),
                  let times = try? JSONDecoder().decode([ClassTime].self, from: data) else { return [] }
            return times
        }
        set {
            scheduleJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "[]"
        }
    }

    /// Next upcoming class time (looks ahead across the whole week, not just today)
    var nextClassTime: ClassTime? {
        scheduleTimes
            .compactMap { ct -> (ClassTime, Int)? in
                guard let mins = ct.minutesUntilNextWeeklyOccurrence() else { return nil }
                return (ct, mins)
            }
            .sorted { $0.1 < $1.1 }
            .first?.0
    }

    var minutesUntilNext: Int? {
        scheduleTimes
            .compactMap { $0.minutesUntilNextWeeklyOccurrence() }
            .min()
    }

    var isFreeWindow: Bool {
        // Only meaningful if class is today and >15 min away
        guard let todayMins = scheduleTimes.compactMap({ $0.minutesUntilToday() }).min()
        else { return false }
        return todayMins > 15
    }

    var topicNames: [String] {
        SubjectTopicPreferences.orderedTopics(for: self)
    }

    var notesByTopic: [(topic: String, notes: [Note])] {
        topicNames.compactMap { topic in
            let value = notes.filter {
                $0.topicName.localizedCaseInsensitiveCompare(topic) == .orderedSame
            }
            guard !value.isEmpty else { return nil }
            return (
                topic: topic,
                notes: value.sorted { $0.createdAt > $1.createdAt }
            )
        }
    }

    func moveTopics(fromOffsets: IndexSet, toOffset: Int) {
        SubjectTopicPreferences.moveTopics(for: self, fromOffsets: fromOffsets, toOffset: toOffset)
    }

    func renameTopic(from oldName: String, to newName: String) {
        SubjectTopicPreferences.renameTopic(for: self, from: oldName, to: newName)
    }
}

private enum SubjectTopicPreferences {
    private static let defaults = UserDefaults.standard

    static func orderedTopics(for subject: Subject) -> [String] {
        let available = availableTopics(for: subject)
        guard !available.isEmpty else { return [] }

        let stored = storedTopicOrder(for: subject.id)
        let resolved = merge(stored: stored, with: available)
        save(resolved, for: subject.id)
        return resolved
    }

    static func moveTopics(for subject: Subject, fromOffsets: IndexSet, toOffset: Int) {
        var order = orderedTopics(for: subject)
        let moving = fromOffsets.map { order[$0] }
        order.removeAll { candidate in
            moving.contains { $0.localizedCaseInsensitiveCompare(candidate) == .orderedSame }
        }
        let removedBeforeDestination = fromOffsets.filter { $0 < toOffset }.count
        let adjustedOffset = toOffset - removedBeforeDestination
        let insertionIndex = min(max(0, adjustedOffset), order.count)
        order.insert(contentsOf: moving, at: insertionIndex)
        save(dedupe(order), for: subject.id)
    }

    static func renameTopic(for subject: Subject, from oldName: String, to newName: String) {
        let source = normalize(oldName)
        let target = normalize(newName)
        guard source != target else { return }

        for note in subject.notes where note.topicName.localizedCaseInsensitiveCompare(source) == .orderedSame {
            note.topicName = target
        }

        var order = orderedTopics(for: subject).map { current in
            current.localizedCaseInsensitiveCompare(source) == .orderedSame ? target : current
        }
        order = dedupe(order + availableTopics(for: subject))
        save(order, for: subject.id)
    }

    private static func availableTopics(for subject: Subject) -> [String] {
        dedupe(subject.notes.map { $0.topicName })
    }

    private static func merge(stored: [String], with available: [String]) -> [String] {
        let kept = stored.filter { candidate in
            available.contains { $0.localizedCaseInsensitiveCompare(candidate) == .orderedSame }
        }
        let extras = available.filter { candidate in
            kept.contains { $0.localizedCaseInsensitiveCompare(candidate) == .orderedSame } == false
        }
        return dedupe(kept + extras.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending })
    }

    private static func dedupe(_ topics: [String]) -> [String] {
        var seen: [String] = []
        for topic in topics.map(normalize) {
            guard seen.contains(where: { $0.localizedCaseInsensitiveCompare(topic) == .orderedSame }) == false else { continue }
            seen.append(topic)
        }
        return seen
    }

    private static func normalize(_ topic: String) -> String {
        let trimmed = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Unsorted" : trimmed
    }

    private static func save(_ topics: [String], for subjectID: UUID) {
        defaults.set(topics, forKey: key(for: subjectID))
    }

    private static func storedTopicOrder(for subjectID: UUID) -> [String] {
        defaults.stringArray(forKey: key(for: subjectID)) ?? []
    }

    private static func key(for subjectID: UUID) -> String {
        "bc_topic_order_\(subjectID.uuidString)"
    }
}
