import Foundation
import SwiftData

@Model
final class ProjectTask {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var project: ClientProject?

    @Relationship(deleteRule: .nullify, inverse: \WorkSession.task)
    var sessions: [WorkSession]

    init(
        title: String,
        project: ClientProject,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.title = title
        self.createdAt = createdAt
        self.project = project
        self.sessions = []
    }
}

extension ProjectTask {
    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Unbenannte Aufgabe" : trimmed
    }
}
