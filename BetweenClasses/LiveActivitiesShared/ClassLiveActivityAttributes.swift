import Foundation
import ActivityKit

struct ClassLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var subjectName: String
        var room: String
        var status: SessionStatus
        var startDate: Date
        var endDate: Date
        var lastSynced: Date
    }

    enum SessionStatus: String, Codable, Hashable {
        case upcoming
        case inSession
        case betweenClasses

        var label: String {
            switch self {
            case .upcoming: return "Up Next"
            case .inSession: return "Live Now"
            case .betweenClasses: return "Free Window"
            }
        }

        var systemImage: String {
            switch self {
            case .upcoming: return "calendar.badge.clock"
            case .inSession: return "dot.radiowaves.left.and.right"
            case .betweenClasses: return "cup.and.saucer"
            }
        }
    }

    var ownerName: String
}
