import Foundation

struct iCalService {
    static func parseSchedule(from url: URL) async throws -> [ClassTime] {
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let raw = String(data: data, encoding: .utf8) else {
            throw iCalError.invalidData
        }
        return parse(raw)
    }

    static func parseScheduleFromString(_ raw: String) -> [ClassTime] {
        parse(raw)
    }

    private static func parse(_ raw: String) -> [ClassTime] {
        var results: [ClassTime] = []
        let lines = raw.components(separatedBy: .newlines)
        var inEvent = false
        var dtstart: String?
        var dtend: String?

        for line in lines {
            let l = line.trimmingCharacters(in: .whitespaces)
            if l == "BEGIN:VEVENT" {
                inEvent = true
                dtstart = nil; dtend = nil
            } else if l == "END:VEVENT", inEvent {
                if let s = dtstart, let e = dtend,
                   let ct = classTime(from: s, end: e) {
                    results.append(ct)
                }
                inEvent = false
            } else if inEvent {
                if l.hasPrefix("DTSTART") {
                    dtstart = l.components(separatedBy: ":").last
                } else if l.hasPrefix("DTEND") {
                    dtend = l.components(separatedBy: ":").last
                }
            }
        }
        return results
    }

    private static func classTime(from startStr: String, end endStr: String) -> ClassTime? {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")

        let formats = ["yyyyMMdd'T'HHmmssZ", "yyyyMMdd'T'HHmmss", "yyyyMMdd"]
        var startDate: Date?
        var endDate: Date?

        for f in formats {
            fmt.dateFormat = f
            if startDate == nil { startDate = fmt.date(from: startStr) }
            if endDate == nil   { endDate   = fmt.date(from: endStr) }
            if startDate != nil && endDate != nil { break }
        }

        guard let s = startDate, let e = endDate else { return nil }
        let cal = Calendar.current
        let sc = cal.dateComponents([.weekday, .hour, .minute], from: s)
        let ec = cal.dateComponents([.hour, .minute], from: e)

        return ClassTime(
            weekday:    sc.weekday ?? 2,
            startHour:  sc.hour ?? 9,
            startMin:   sc.minute ?? 0,
            endHour:    ec.hour ?? 10,
            endMin:     ec.minute ?? 0,
            room:       ""
        )
    }
}

enum iCalError: Error, LocalizedError {
    case invalidData

    var errorDescription: String? { "Could not parse iCal data." }
}
