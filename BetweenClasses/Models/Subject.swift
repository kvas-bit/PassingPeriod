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
        let names = notes
            .map { $0.topicName.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.isEmpty ? "Unsorted" : $0 }
        return Array(Set(names)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var notesByTopic: [(topic: String, notes: [Note])] {
        let grouped = Dictionary(grouping: notes) { note in
            let trimmed = note.topicName.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Unsorted" : trimmed
        }
        return grouped
            .map { key, value in
                (
                    topic: key,
                    notes: value.sorted { $0.createdAt > $1.createdAt }
                )
            }
            .sorted { $0.topic.localizedCaseInsensitiveCompare($1.topic) == .orderedAscending }
    }
}
