import Foundation
import SwiftData
import ActivityKit

@MainActor
final class LiveActivitySyncService {
    static let shared = LiveActivitySyncService()

    private init() {}

    func sync(using modelContext: ModelContext) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let descriptor = FetchDescriptor<Subject>(sortBy: [SortDescriptor(\Subject.name)])
        guard let subjects = try? modelContext.fetch(descriptor) else { return }

        guard let snapshot = nextSnapshot(from: subjects) else {
            Task { await endAllActivities() }
            return
        }

        Task {
            await upsertActivity(with: snapshot)
        }
    }

    func endAllActivities() async {
        for activity in Activity<ClassLiveActivityAttributes>.activities {
            await activity.end(activity.content, dismissalPolicy: .immediate)
        }
    }

    private func upsertActivity(with state: ClassLiveActivityAttributes.ContentState) async {
        let content = ActivityContent(state: state, staleDate: state.endDate)

        if let existing = Activity<ClassLiveActivityAttributes>.activities.first {
            await existing.update(content)
            return
        }

        let attributes = ClassLiveActivityAttributes(ownerName: "Ishan")
        _ = try? Activity.request(attributes: attributes, content: content)
    }

    private func nextSnapshot(from subjects: [Subject]) -> ClassLiveActivityAttributes.ContentState? {
        let now = Date()
        let schedule = subjects.flatMap { subject in
            subject.scheduleTimes.compactMap { classTime in
                concreteSession(for: classTime, subjectName: subject.name, now: now)
            }
        }

        if let current = schedule.first(where: { $0.startDate <= now && now < $0.endDate }) {
            return ClassLiveActivityAttributes.ContentState(
                subjectName: current.subjectName,
                room: current.room,
                status: .inSession,
                startDate: current.startDate,
                endDate: current.endDate,
                lastSynced: now
            )
        }

        guard let upcoming = schedule
            .filter({ $0.startDate > now })
            .sorted(by: { $0.startDate < $1.startDate })
            .first else { return nil }

        let status: ClassLiveActivityAttributes.SessionStatus =
            upcoming.startDate.timeIntervalSince(now) <= (30 * 60) ? .upcoming : .betweenClasses

        return ClassLiveActivityAttributes.ContentState(
            subjectName: upcoming.subjectName,
            room: upcoming.room,
            status: status,
            startDate: upcoming.startDate,
            endDate: upcoming.endDate,
            lastSynced: now
        )
    }

    private func concreteSession(for classTime: ClassTime, subjectName: String, now: Date) -> SessionSnapshot? {
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: now)
        let minutesNow = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        let classStartMins = classTime.startHour * 60 + classTime.startMin

        for daysAhead in 0...7 {
            let day = ((currentWeekday - 1 + daysAhead) % 7) + 1
            guard day == classTime.weekday else { continue }

            guard let date = calendar.date(byAdding: .day, value: daysAhead, to: now),
                  let dayStart = calendar.dateInterval(of: .day, for: date)?.start else { continue }

            let startDate = calendar.date(byAdding: .minute, value: classStartMins, to: dayStart) ?? now
            let endDate = calendar.date(byAdding: .minute, value: classTime.endHour * 60 + classTime.endMin, to: dayStart) ?? startDate

            if daysAhead == 0 && classStartMins < minutesNow && now > endDate { continue }

            return SessionSnapshot(subjectName: subjectName, room: classTime.room, startDate: startDate, endDate: endDate)
        }

        return nil
    }
}

private struct SessionSnapshot {
    let subjectName: String
    let room: String
    let startDate: Date
    let endDate: Date
}
