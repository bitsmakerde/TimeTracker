import Foundation
import SwiftData

@Model
final class ClientProject {
    @Attribute(.unique) var id: UUID
    var clientName: String
    var name: String
    var notes: String
    var hourlyRate: Double?
    var archivedAt: Date?
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \WorkSession.project)
    var sessions: [WorkSession]

    @Relationship(deleteRule: .cascade, inverse: \ProjectTask.project)
    var tasks: [ProjectTask]

    init(
        clientName: String,
        name: String,
        notes: String = "",
        hourlyRate: Double? = nil,
        archivedAt: Date? = nil,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.clientName = clientName
        self.name = name
        self.notes = notes
        self.hourlyRate = hourlyRate
        self.archivedAt = archivedAt
        self.createdAt = createdAt
        self.sessions = []
        self.tasks = []
    }
}

extension ClientProject {
    var displayClientName: String {
        let trimmed = clientName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Ohne Kunde" : trimmed
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Unbenanntes Projekt" : trimmed
    }

    var sortedSessions: [WorkSession] {
        sessions.sorted { $0.startedAt > $1.startedAt }
    }

    var sortedTasks: [ProjectTask] {
        tasks.sorted { lhs, rhs in
            let titleComparison = lhs.displayTitle.localizedCaseInsensitiveCompare(rhs.displayTitle)

            if titleComparison == .orderedSame {
                return lhs.createdAt < rhs.createdAt
            }

            return titleComparison == .orderedAscending
        }
    }

    var isArchived: Bool {
        archivedAt != nil
    }

    var hasHourlyRate: Bool {
        hourlyRate != nil
    }

    var effectiveHourlyRate: Double {
        max(hourlyRate ?? 0, 0)
    }

    func billedAmount(for duration: TimeInterval) -> Double? {
        guard let hourlyRate else {
            return nil
        }

        return max(duration / 3600, 0) * max(hourlyRate, 0)
    }
}
