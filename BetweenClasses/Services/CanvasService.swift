import Foundation
import SwiftUI

struct CanvasService {
    private static var school: String {
        (try? KeychainService.retrieve(KeychainKey.canvasSchool)) ?? ""
    }
    private static var token: String {
        (try? KeychainService.retrieve(KeychainKey.canvasToken)) ?? ""
    }

    // MARK: - Network configuration
    // Use a shared session with explicit timeouts so requests don't hang indefinitely.
    // Default timeout: 30 s per-request, 60 s overall resource limit.
    private static var session: URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }

    private static var baseURL: String {
        let s = school
        // If user entered a full domain (e.g. "canvas.ucdavis.edu"), use it directly.
        // Otherwise assume Instructure-hosted subdomain (e.g. "ucdavis" → "ucdavis.instructure.com").
        if s.contains(".") {
            return "https://\(s)/api/v1"
        }
        return "https://\(s).instructure.com/api/v1"
    }

    // MARK: - Fetch enrolled courses → [Subject]

    static func fetchCourses() async throws -> [Subject] {
        guard !school.isEmpty, !token.isEmpty else { throw CanvasError.notConfigured }

        guard let url = URL(string: "\(baseURL)/courses?enrollment_state=active&per_page=50") else {
            throw CanvasError.httpError(statusCode: -1, reason: "Invalid URL")
        }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: req)
        try validateHTTPResponse(response)

        let courses = try JSONDecoder().decode([CanvasCourse].self, from: data)
        return courses.map { course in
            let resolvedName = course.courseCode ?? course.name
            return Subject(
                name: resolvedName,
                instructor: "",
                colorHex: Color.generatedSubjectHex(for: resolvedName),
                canvasID: String(course.id)
            )
        }
    }

    // MARK: - Fetch calendar events for a course

    static func fetchCalendarEvents(courseID: String) async throws -> [ClassTime] {
        guard !school.isEmpty, !token.isEmpty else { throw CanvasError.notConfigured }

        guard let url = URL(string: "\(baseURL)/calendar_events?context_codes[]=course_\(courseID)&per_page=100") else {
            throw CanvasError.httpError(statusCode: -1, reason: "Invalid URL")
        }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: req)
        try validateHTTPResponse(response)

        let events = try JSONDecoder().decode([CanvasCalendarEvent].self, from: data)
        return events.compactMap { event -> ClassTime? in
            guard let start = event.startAt, let end = event.endAt else { return nil }
            let cal = Calendar.current
            let startComps = cal.dateComponents([.weekday, .hour, .minute], from: start)
            let endComps   = cal.dateComponents([.hour, .minute],           from: end)
            return ClassTime(
                weekday:   startComps.weekday ?? 2,
                startHour: startComps.hour   ?? 9,
                startMin:  startComps.minute ?? 0,
                endHour:   endComps.hour     ?? 10,
                endMin:    endComps.minute   ?? 0,
                room:      event.locationName ?? ""
            )
        }
    }

    // MARK: - HTTP validation helper

    private static func validateHTTPResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw CanvasError.httpError(statusCode: -1, reason: "Non-HTTP response")
        }
        switch http.statusCode {
        case 200..<300: return
        case 401: throw CanvasError.unauthorized
        case 403: throw CanvasError.forbidden
        case 429: throw CanvasError.rateLimited
        case 500..<600: throw CanvasError.serverError(statusCode: http.statusCode)
        default: throw CanvasError.httpError(statusCode: http.statusCode, reason: nil)
        }
    }
}

// MARK: - Canvas API models

private struct CanvasCourse: Decodable {
    let id: Int
    let name: String
    let courseCode: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case courseCode = "course_code"
    }
}

private struct CanvasCalendarEvent: Decodable {
    let id: Int
    let startAt: Date?
    let endAt: Date?
    let locationName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case startAt = "start_at"
        case endAt = "end_at"
        case locationName = "location_name"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        locationName = try? c.decode(String.self, forKey: .locationName)
        let fmt = ISO8601DateFormatter()
        startAt = (try? c.decode(String.self, forKey: .startAt)).flatMap { fmt.date(from: $0) }
        endAt   = (try? c.decode(String.self, forKey: .endAt)).flatMap   { fmt.date(from: $0) }
    }
}

enum CanvasError: Error, LocalizedError {
    case notConfigured
    case httpError(statusCode: Int, reason: String?)
    case unauthorized
    case forbidden
    case rateLimited
    case serverError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Canvas credentials not set. Complete onboarding."
        case .httpError(let code, let reason):
            return reason != nil
                ? "Canvas request failed (HTTP \(code)): \(reason!)"
                : "Canvas request failed (HTTP \(code))."
        case .unauthorized:
            return "Canvas token is invalid or expired. Please re-authenticate."
        case .forbidden:
            return "Access denied to Canvas API. Check account permissions."
        case .rateLimited:
            return "Canvas API rate limit reached. Please try again later."
        case .serverError(let code):
            return "Canvas server error (HTTP \(code)). Try again shortly."
        }
    }
}