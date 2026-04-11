import Foundation

struct ClassTime: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var weekday: Int     // 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri (Calendar.weekday)
    var startHour: Int
    var startMin: Int
    var endHour: Int
    var endMin: Int
    var room: String

    var startComponents: DateComponents {
        DateComponents(hour: startHour, minute: startMin)
    }

    var endComponents: DateComponents {
        DateComponents(hour: endHour, minute: endMin)
    }

    var displayTime: String {
        func to12(_ h: Int) -> Int { h == 0 ? 12 : (h > 12 ? h - 12 : h) }
        let startStr = String(format: "%d:%02d", to12(startHour), startMin)
        let endStr   = String(format: "%d:%02d", to12(endHour), endMin)
        let ampm     = endHour >= 12 ? "PM" : "AM"
        return "\(startStr)–\(endStr) \(ampm)"
    }

    var weekdayName: String {
        let names = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return names[safe: weekday] ?? ""
    }

    /// Returns true if this class is happening right now
    func isHappeningNow() -> Bool {
        let cal = Calendar.current
        let now = Date()
        guard cal.component(.weekday, from: now) == weekday else { return false }
        let h = cal.component(.hour, from: now)
        let m = cal.component(.minute, from: now)
        let nowMins   = h * 60 + m
        let startMins = startHour * 60 + startMin
        let endMins   = endHour * 60 + endMin
        return nowMins >= startMins && nowMins < endMins
    }

    /// Minutes until this class starts today; nil if not today or already past
    func minutesUntilToday() -> Int? {
        let cal = Calendar.current
        let now = Date()
        guard cal.component(.weekday, from: now) == weekday else { return nil }
        let h = cal.component(.hour, from: now)
        let m = cal.component(.minute, from: now)
        let nowMins   = h * 60 + m
        let startMins = startHour * 60 + startMin
        let diff = startMins - nowMins
        return diff > 0 ? diff : nil
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
