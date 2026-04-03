import Foundation
import SwiftData

enum TrackingManagerError: LocalizedError {
    case invalidDateRange
    case futureDateNotAllowed
    case activeSessionEditingNotAllowed
    case archivedProjectNotEditable

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
        }
    }
}

struct TrackingManager {
    func startTracking(
        project: ClientProject,
        in context: ModelContext,
        at referenceDate: Date = .now
    ) throws {
        guard !project.isArchived else {
            throw TrackingManagerError.archivedProjectNotEditable
        }

        try closeAllActiveSessions(in: context, at: referenceDate)

        let session = WorkSession(project: project, startedAt: referenceDate)
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
        startedAt: Date,
        endedAt: Date,
        in context: ModelContext,
        now: Date = .now
    ) throws {
        guard !project.isArchived else {
            throw TrackingManagerError.archivedProjectNotEditable
        }

        try validateManualSessionDates(
            startedAt: startedAt,
            endedAt: endedAt,
            now: now
        )

        let session = WorkSession(
            project: project,
            startedAt: startedAt,
            endedAt: endedAt
        )

        context.insert(session)
        try context.save()
    }

    func updateManualSession(
        _ session: WorkSession,
        startedAt: Date,
        endedAt: Date,
        in context: ModelContext,
        now: Date = .now
    ) throws {
        guard !session.isActive else {
            throw TrackingManagerError.activeSessionEditingNotAllowed
        }

        try validateManualSessionDates(
            startedAt: startedAt,
            endedAt: endedAt,
            now: now
        )

        session.startedAt = startedAt
        session.endedAt = endedAt
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
}
