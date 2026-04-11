import Foundation

struct iCalService {

    // MARK: - URL entry points

    static func parseGrouped(from url: URL) async throws -> [String: [ClassTime]] {
        let normalized = url.absoluteString
            .replacingOccurrences(of: "webcal://", with: "https://")
        guard let resolvedURL = URL(string: normalized) else { throw iCalError.invalidData }
        let (data, _) = try await URLSession.shared.data(from: resolvedURL)
        guard let raw = String(data: data, encoding: .utf8) else {
            throw iCalError.invalidData
        }
        return parseGrouped(unfold(raw))
    }

    static func parseScheduleFromString(_ raw: String) -> [ClassTime] {
        parseGrouped(unfold(raw)).values.flatMap { $0 }
    }

    // MARK: - RFC 5545 line unfolding

    /// Strip soft line-breaks: CRLF (or LF) followed by a whitespace char.
    private static func unfold(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "\r\n ", with: "")
            .replacingOccurrences(of: "\r\n\t", with: "")
            .replacingOccurrences(of: "\n ", with: "")
            .replacingOccurrences(of: "\n\t", with: "")
    }

    // MARK: - Grouped parser

    static func parseGrouped(_ raw: String) -> [String: [ClassTime]] {
        var result: [String: [ClassTime]] = [:]
        let lines = raw.components(separatedBy: .newlines)
        var inEvent = false
        var dtStartLine: String?
        var dtEndLine: String?
        var summary: String?
        var location: String?
        var rrule: String?

        for line in lines {
            let l = line.trimmingCharacters(in: .whitespaces)
            if l == "BEGIN:VEVENT" {
                inEvent = true
                dtStartLine = nil; dtEndLine = nil
                summary = nil; location = nil; rrule = nil
            } else if l == "END:VEVENT", inEvent {
                if let startLine = dtStartLine,
                   let endLine   = dtEndLine,
                   let name      = summary, !name.isEmpty {
                    let times = buildClassTimes(
                        startLine: startLine,
                        endLine: endLine,
                        rrule: rrule,
                        room: location ?? ""
                    )
                    var existing = result[name] ?? []
                    for ct in times {
                        let isDupe = existing.contains {
                            $0.weekday == ct.weekday &&
                            $0.startHour == ct.startHour &&
                            $0.startMin  == ct.startMin
                        }
                        if !isDupe { existing.append(ct) }
                    }
                    result[name] = existing
                }
                inEvent = false
            } else if inEvent {
                if l.hasPrefix("DTSTART") {
                    dtStartLine = l
                } else if l.hasPrefix("DTEND") {
                    dtEndLine = l
                } else if l.hasPrefix("SUMMARY:") {
                    summary = String(l.dropFirst(8)).trimmingCharacters(in: .whitespaces)
                } else if l.hasPrefix("LOCATION:") {
                    location = String(l.dropFirst(9)).trimmingCharacters(in: .whitespaces)
                } else if l.hasPrefix("RRULE:") {
                    rrule = String(l.dropFirst(6))
                }
            }
        }
        return result
    }

    // MARK: - ClassTime construction

    /// Build one or more ClassTimes from a VEVENT.
    /// If RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR is present, expands into one ClassTime per day.
    private static func buildClassTimes(startLine: String, endLine: String,
                                        rrule: String?, room: String) -> [ClassTime] {
        guard let startStr = propertyValue(startLine),
              let endStr   = propertyValue(endLine),
              let startDate = parseDate(startStr, tzid: extractTZID(startLine)),
              let endDate   = parseDate(endStr,   tzid: extractTZID(endLine)) else { return [] }

        let cal = Calendar.current
        let sc = cal.dateComponents([.weekday, .hour, .minute], from: startDate)
        let ec = cal.dateComponents([.hour, .minute],           from: endDate)
        let startHour = sc.hour   ?? 9
        let startMin  = sc.minute ?? 0
        let endHour   = ec.hour   ?? 10
        let endMin    = ec.minute ?? 0

        // Expand RRULE BYDAY into multiple ClassTimes (handles "MWF" style schedules)
        if let rule = rrule,
           rule.uppercased().contains("FREQ=WEEKLY"),
           let byday = rruleComponent(rule, key: "BYDAY") {

            let dayMap = ["MO": 2, "TU": 3, "WE": 4, "TH": 5, "FR": 6, "SA": 7, "SU": 1]
            let weekdays = byday
                .components(separatedBy: ",")
                .compactMap { dayMap[$0.trimmingCharacters(in: .whitespaces)] }

            if !weekdays.isEmpty {
                return weekdays.map { wd in
                    ClassTime(weekday: wd, startHour: startHour, startMin: startMin,
                              endHour: endHour, endMin: endMin, room: room)
                }
            }
        }

        // Single occurrence — use the DTSTART weekday
        return [ClassTime(
            weekday:   sc.weekday ?? 2,
            startHour: startHour,
            startMin:  startMin,
            endHour:   endHour,
            endMin:    endMin,
            room:      room
        )]
    }

    // MARK: - Helpers

    /// Extract value after the last colon (handles DTSTART;TZID=...:value)
    private static func propertyValue(_ line: String) -> String? {
        guard let idx = line.lastIndex(of: ":") else { return nil }
        return String(line[line.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
    }

    /// Extract TZID parameter value from a property line, e.g. "America/Los_Angeles"
    private static func extractTZID(_ line: String) -> String? {
        guard let tzRange = line.range(of: "TZID=") else { return nil }
        let after = line[tzRange.upperBound...]
        if let colon = after.firstIndex(of: ":") {
            return String(after[..<colon])
        }
        return nil
    }

    /// Extract a key from a RRULE string like "FREQ=WEEKLY;BYDAY=MO,WE,FR"
    private static func rruleComponent(_ rule: String, key: String) -> String? {
        for part in rule.components(separatedBy: ";") {
            let kv = part.components(separatedBy: "=")
            if kv.count == 2, kv[0].trimmingCharacters(in: .whitespaces).uppercased() == key {
                return kv[1].trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    /// Parse a date string with optional timezone. Falls back through multiple formats.
    private static func parseDate(_ str: String, tzid: String? = nil) -> Date? {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        if let tzid, let tz = TimeZone(identifier: tzid) {
            fmt.timeZone = tz
        }
        for f in ["yyyyMMdd'T'HHmmssZ", "yyyyMMdd'T'HHmmss", "yyyyMMdd"] {
            fmt.dateFormat = f
            if let d = fmt.date(from: str) { return d }
        }
        // Last resort: strip Z and treat as floating local time
        if str.hasSuffix("Z") {
            fmt.dateFormat = "yyyyMMdd'T'HHmmss"
            if let d = fmt.date(from: String(str.dropLast())) { return d }
        }
        return nil
    }
}

enum iCalError: Error, LocalizedError {
    case invalidData
    var errorDescription: String? { "Could not parse iCal data." }
}
