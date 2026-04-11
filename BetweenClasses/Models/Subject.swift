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
        guard let mins = minutesUntilNext else { return false }
        return mins > 15
    }
}
