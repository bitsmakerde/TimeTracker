import Foundation
import SwiftData

@Model
final class WorkSession {
    var id: UUID = UUID()
    var startedAt: Date = Date.now
    var endedAt: Date?
    var project: ClientProject? = nil
    var task: ProjectTask? = nil

    init(
        project: ClientProject,
        task: ProjectTask? = nil,
        startedAt: Date = .now,
        endedAt: Date? = nil
    ) {
        self.id = UUID()
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.project = project
        self.task = task
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

    var displayTaskTitle: String {
        task?.displayTitle ?? "Ohne Aufgabe"
    }
}
