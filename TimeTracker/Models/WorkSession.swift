import Foundation
import SwiftData

@Model
final class WorkSession {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var project: ClientProject?

    init(
        project: ClientProject,
        startedAt: Date = .now,
        endedAt: Date? = nil
    ) {
        self.id = UUID()
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.project = project
    }
}

extension WorkSession {
    var isActive: Bool {
        endedAt == nil
    }

    var recordedDuration: TimeInterval {
        duration(referenceDate: .now)
    }

    func duration(referenceDate: Date) -> TimeInterval {
        let effectiveEnd = endedAt ?? referenceDate
        return max(effectiveEnd.timeIntervalSince(startedAt), 0)
    }
}
