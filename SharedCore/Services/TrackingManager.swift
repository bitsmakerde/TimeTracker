import Foundation
import SwiftData

enum TrackingManagerError: LocalizedError, Equatable {
    case invalidDateRange
    case futureDateNotAllowed
    case activeSessionEditingNotAllowed
    case archivedProjectNotEditable
    case invalidTaskAssignment

    var errorDescription: String? {
        switch self {
        case .invalidDateRange:
            return "Das Enddatum muss nach dem Startdatum liegen."
        case .futureDateNotAllowed:
            return "Nachgetragene Zeiteintraege duerfen nicht in der Zukunft liegen."
        case .activeSessionEditingNotAllowed:
            return "Laufende Zeiteintraege koennen erst nach dem Stoppen bearbeitet werden."
        case .archivedProjectNotEditable:
            return "Archivierte Projekte muessen zuerst reaktiviert werden."
        case .invalidTaskAssignment:
            return "Die ausgewaehlte Aufgabe gehoert nicht zu diesem Projekt."
        }
    }
}

struct TrackingManager {
    func startTracking(
        project: ClientProject,
        task: ProjectTask? = nil,
        in context: ModelContext,
        at referenceDate: Date = .now
    ) throws {
        guard !project.isArchived else {
            throw TrackingManagerError.archivedProjectNotEditable
        }

        try validateTask(task, belongsTo: project)
        try closeAllActiveSessions(in: context, at: referenceDate)

        let session = WorkSession(
            project: project,
            task: task,
            startedAt: referenceDate
        )
        context.insert(session)
        try context.save()
    }

    func stopActiveTracking(
        in context: ModelContext,
        at referenceDate: Date = .now
    ) throws {
        try closeAllActiveSessions(in: context, at: referenceDate)
        try context.save()
    }

    func addManualSession(
        for project: ClientProject,
        task: ProjectTask?,
        startedAt: Date,
        endedAt: Date,
        in context: ModelContext,
        now: Date = .now
    ) throws {
        guard !project.isArchived else {
            throw TrackingManagerError.archivedProjectNotEditable
        }

        try validateTask(task, belongsTo: project)
        try validateManualSessionDates(
            startedAt: startedAt,
            endedAt: endedAt,
            now: now
        )

        let session = WorkSession(
            project: project,
            task: task,
            startedAt: startedAt,
            endedAt: endedAt
        )

        context.insert(session)
        try context.save()
    }

    func updateManualSession(
        _ session: WorkSession,
        task: ProjectTask?,
        startedAt: Date,
        endedAt: Date,
        in context: ModelContext,
        now: Date = .now
    ) throws {
        guard !session.isActive else {
            throw TrackingManagerError.activeSessionEditingNotAllowed
        }

        if let project = session.project {
            try validateTask(task, belongsTo: project)
        }

        try validateManualSessionDates(
            startedAt: startedAt,
            endedAt: endedAt,
            now: now
        )

        session.startedAt = startedAt
        session.endedAt = endedAt
        session.task = task
        try context.save()
    }

    func archiveProject(
        _ project: ClientProject,
        in context: ModelContext,
        at referenceDate: Date = .now
    ) throws {
        for session in project.sessions where session.isActive {
            session.endedAt = max(session.startedAt, referenceDate)
        }

        project.archivedAt = referenceDate
        try context.save()
    }

    func restoreProject(
        _ project: ClientProject,
        in context: ModelContext
    ) throws {
        project.archivedAt = nil
        try context.save()
    }

    func deleteProject(
        _ project: ClientProject,
        in context: ModelContext
    ) throws {
        context.delete(project)
        try context.save()
    }

    func deleteSession(
        _ session: WorkSession,
        in context: ModelContext
    ) throws {
        context.delete(session)
        try context.save()
    }

    private func closeAllActiveSessions(
        in context: ModelContext,
        at referenceDate: Date
    ) throws {
        let descriptor = FetchDescriptor<WorkSession>(
            predicate: #Predicate<WorkSession> { session in
                session.endedAt == nil
            },
            sortBy: [SortDescriptor(\WorkSession.startedAt, order: .reverse)]
        )

        let activeSessions = try context.fetch(descriptor)

        for session in activeSessions {
            session.endedAt = max(session.startedAt, referenceDate)
        }
    }

    private func validateManualSessionDates(
        startedAt: Date,
        endedAt: Date,
        now: Date
    ) throws {
        guard endedAt > startedAt else {
            throw TrackingManagerError.invalidDateRange
        }

        guard startedAt <= now, endedAt <= now else {
            throw TrackingManagerError.futureDateNotAllowed
        }
    }

    private func validateTask(
        _ task: ProjectTask?,
        belongsTo project: ClientProject
    ) throws {
        guard let task else {
            return
        }

        guard task.project?.id == project.id else {
            throw TrackingManagerError.invalidTaskAssignment
        }
    }
}
