import Foundation
import SwiftData
import Testing
@testable import TimeTracker

@Suite("TrackingManager")
@MainActor
struct TrackingManagerTests {
    @Test("startTracking closes previous active session and creates a new one")
    func startTrackingStopsPrevious() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let manager = TrackingManager()

        let firstProject = ClientProject(clientName: "A", name: "First")
        let secondProject = ClientProject(clientName: "A", name: "Second")
        context.insert(firstProject)
        context.insert(secondProject)
        try context.save()

        let firstStart = Date(timeIntervalSince1970: 100)
        let secondStart = Date(timeIntervalSince1970: 200)

        try manager.startTracking(
            project: firstProject,
            in: context,
            at: firstStart
        )
        try manager.startTracking(
            project: secondProject,
            in: context,
            at: secondStart
        )

        let sessions = try context.fetch(FetchDescriptor<WorkSession>())
        #expect(sessions.count == 2)

        let firstSession = sessions.first { $0.project?.id == firstProject.id }
        let secondSession = sessions.first { $0.project?.id == secondProject.id }

        #expect(firstSession != nil)
        #expect(secondSession != nil)
        #expect(firstSession?.endedAt == secondStart)
        #expect(secondSession?.endedAt == nil)
    }

    @Test("startTracking rejects archived projects")
    func startTrackingRejectsArchivedProject() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let manager = TrackingManager()

        let project = ClientProject(clientName: "A", name: "Archived")
        project.archivedAt = Date(timeIntervalSince1970: 1)
        context.insert(project)
        try context.save()

        try expectTrackingError(.archivedProjectNotEditable) {
            try manager.startTracking(project: project, in: context)
        }
    }

    @Test("startTracking rejects tasks from other projects")
    func startTrackingRejectsForeignTask() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let manager = TrackingManager()

        let project = ClientProject(clientName: "A", name: "Main")
        let otherProject = ClientProject(clientName: "A", name: "Other")
        let foreignTask = ProjectTask(title: "Foreign", project: otherProject)
        context.insert(project)
        context.insert(otherProject)
        context.insert(foreignTask)
        try context.save()

        try expectTrackingError(.invalidTaskAssignment) {
            try manager.startTracking(
                project: project,
                task: foreignTask,
                in: context
            )
        }
    }

    @Test("startTracking stores selected task for the running session")
    func startTrackingStoresTask() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let manager = TrackingManager()

        let project = ClientProject(clientName: "A", name: "Main")
        let task = ProjectTask(title: "Bugfix", project: project)
        context.insert(project)
        context.insert(task)
        try context.save()

        let start = Date(timeIntervalSince1970: 123)
        try manager.startTracking(
            project: project,
            task: task,
            in: context,
            at: start
        )

        let session = try #require(context.fetch(FetchDescriptor<WorkSession>()).first)
        #expect(session.task?.id == task.id)
        #expect(session.startedAt == start)
        #expect(session.endedAt == nil)
    }

    @Test("stopActiveTracking closes all active sessions")
    func stopActiveTrackingClosesSessions() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let manager = TrackingManager()

        let project = ClientProject(clientName: "A", name: "Project")
        context.insert(project)
        try context.save()

        let start = Date(timeIntervalSince1970: 100)
        let stop = Date(timeIntervalSince1970: 500)
        try manager.startTracking(project: project, in: context, at: start)
        try manager.stopActiveTracking(in: context, at: stop)

        let sessions = try context.fetch(FetchDescriptor<WorkSession>())
        #expect(sessions.count == 1)
        #expect(sessions.first?.endedAt == stop)
    }

    @Test("stopActiveTracking never backdates a running session")
    func stopActiveTrackingDoesNotBackdate() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let manager = TrackingManager()

        let project = ClientProject(clientName: "A", name: "Project")
        context.insert(project)
        try context.save()

        let start = Date(timeIntervalSince1970: 500)
        try manager.startTracking(project: project, in: context, at: start)
        try manager.stopActiveTracking(in: context, at: Date(timeIntervalSince1970: 100))

        let session = try #require(context.fetch(FetchDescriptor<WorkSession>()).first)
        #expect(session.endedAt == start)
    }

    @Test("addManualSession validates ranges and task ownership")
    func addManualSessionValidation() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let manager = TrackingManager()

        let project = ClientProject(clientName: "A", name: "Project")
        let otherProject = ClientProject(clientName: "A", name: "Other")
        let foreignTask = ProjectTask(title: "Foreign", project: otherProject)
        context.insert(project)
        context.insert(otherProject)
        context.insert(foreignTask)
        try context.save()

        let start = Date(timeIntervalSince1970: 100)
        let end = Date(timeIntervalSince1970: 200)

        try expectTrackingError(.invalidDateRange) {
            try manager.addManualSession(
                for: project,
                task: nil,
                startedAt: end,
                endedAt: start,
                in: context
            )
        }

        try expectTrackingError(.futureDateNotAllowed) {
            try manager.addManualSession(
                for: project,
                task: nil,
                startedAt: Date(timeIntervalSinceNow: 1000),
                endedAt: Date(timeIntervalSinceNow: 2000),
                in: context
            )
        }

        try expectTrackingError(.invalidTaskAssignment) {
            try manager.addManualSession(
                for: project,
                task: foreignTask,
                startedAt: start,
                endedAt: end,
                in: context
            )
        }
    }

    @Test("addManualSession rejects archived projects")
    func addManualSessionRejectsArchivedProject() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let manager = TrackingManager()

        let project = ClientProject(clientName: "A", name: "Project")
        project.archivedAt = Date(timeIntervalSince1970: 1)
        context.insert(project)
        try context.save()

        try expectTrackingError(.archivedProjectNotEditable) {
            try manager.addManualSession(
                for: project,
                task: nil,
                startedAt: Date(timeIntervalSince1970: 100),
                endedAt: Date(timeIntervalSince1970: 200),
                in: context
            )
        }
    }

    @Test("addManualSession stores closed session with task")
    func addManualSessionStoresSession() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let manager = TrackingManager()

        let project = ClientProject(clientName: "A", name: "Project")
        let task = ProjectTask(title: "Bugfix", project: project)
        context.insert(project)
        context.insert(task)
        try context.save()

        let start = Date(timeIntervalSince1970: 100)
        let end = Date(timeIntervalSince1970: 250)
        try manager.addManualSession(
            for: project,
            task: task,
            startedAt: start,
            endedAt: end,
            in: context
        )

        let sessions = try context.fetch(FetchDescriptor<WorkSession>())
        #expect(sessions.count == 1)
        #expect(sessions.first?.task?.id == task.id)
        #expect(sessions.first?.startedAt == start)
        #expect(sessions.first?.endedAt == end)
    }

    @Test("updateManualSession updates task and time values")
    func updateManualSessionUpdatesData() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let manager = TrackingManager()

        let project = ClientProject(clientName: "A", name: "Project")
        let taskA = ProjectTask(title: "A", project: project)
        let taskB = ProjectTask(title: "B", project: project)
        let session = WorkSession(
            project: project,
            task: taskA,
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 200)
        )
        context.insert(project)
        context.insert(taskA)
        context.insert(taskB)
        context.insert(session)
        try context.save()

        let newStart = Date(timeIntervalSince1970: 300)
        let newEnd = Date(timeIntervalSince1970: 500)
        try manager.updateManualSession(
            session,
            task: taskB,
            startedAt: newStart,
            endedAt: newEnd,
            in: context
        )

        #expect(session.startedAt == newStart)
        #expect(session.endedAt == newEnd)
        #expect(session.task?.id == taskB.id)
    }

    @Test("updateManualSession rejects active sessions")
    func updateManualSessionRejectsActiveSession() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let manager = TrackingManager()

        let project = ClientProject(clientName: "A", name: "Project")
        let session = WorkSession(project: project, startedAt: Date(timeIntervalSince1970: 100))
        context.insert(project)
        context.insert(session)
        try context.save()

        try expectTrackingError(.activeSessionEditingNotAllowed) {
            try manager.updateManualSession(
                session,
                task: nil,
                startedAt: Date(timeIntervalSince1970: 110),
                endedAt: Date(timeIntervalSince1970: 120),
                in: context
            )
        }
    }

    @Test("updateManualSession validates date and task constraints")
    func updateManualSessionValidatesInputs() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let manager = TrackingManager()

        let project = ClientProject(clientName: "A", name: "Project")
        let foreignProject = ClientProject(clientName: "A", name: "Foreign")
        let foreignTask = ProjectTask(title: "Foreign", project: foreignProject)
        let session = WorkSession(
            project: project,
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 200)
        )
        context.insert(project)
        context.insert(foreignProject)
        context.insert(foreignTask)
        context.insert(session)
        try context.save()

        try expectTrackingError(.invalidTaskAssignment) {
            try manager.updateManualSession(
                session,
                task: foreignTask,
                startedAt: Date(timeIntervalSince1970: 110),
                endedAt: Date(timeIntervalSince1970: 120),
                in: context
            )
        }

        try expectTrackingError(.invalidDateRange) {
            try manager.updateManualSession(
                session,
                task: nil,
                startedAt: Date(timeIntervalSince1970: 150),
                endedAt: Date(timeIntervalSince1970: 120),
                in: context
            )
        }

        try expectTrackingError(.futureDateNotAllowed) {
            try manager.updateManualSession(
                session,
                task: nil,
                startedAt: Date(timeIntervalSinceNow: 120),
                endedAt: Date(timeIntervalSinceNow: 240),
                in: context
            )
        }
    }

    @Test("archive and restore update archivedAt and close active sessions")
    func archiveAndRestoreProject() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let manager = TrackingManager()

        let project = ClientProject(clientName: "A", name: "Project")
        let activeSession = WorkSession(
            project: project,
            startedAt: Date(timeIntervalSince1970: 100)
        )
        context.insert(project)
        context.insert(activeSession)
        try context.save()

        let archiveDate = Date(timeIntervalSince1970: 500)
        try manager.archiveProject(project, in: context, at: archiveDate)

        #expect(project.archivedAt == archiveDate)
        #expect(activeSession.endedAt == archiveDate)

        try manager.restoreProject(project, in: context)
        #expect(project.archivedAt == nil)
    }

    @Test("archiveProject closes sessions with non-negative durations")
    func archiveProjectDoesNotBackdateActiveSession() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let manager = TrackingManager()

        let project = ClientProject(clientName: "A", name: "Project")
        let activeSession = WorkSession(
            project: project,
            startedAt: Date(timeIntervalSince1970: 400)
        )
        context.insert(project)
        context.insert(activeSession)
        try context.save()

        try manager.archiveProject(
            project,
            in: context,
            at: Date(timeIntervalSince1970: 200)
        )

        #expect(activeSession.endedAt == activeSession.startedAt)
    }

    @Test("deleteSession and deleteProject remove persisted records")
    func deleteOperations() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let manager = TrackingManager()

        let project = ClientProject(clientName: "A", name: "Project")
        let session = WorkSession(
            project: project,
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 200)
        )
        context.insert(project)
        context.insert(session)
        try context.save()

        try manager.deleteSession(session, in: context)
        var sessions = try context.fetch(FetchDescriptor<WorkSession>())
        #expect(sessions.isEmpty)

        try manager.deleteProject(project, in: context)
        let projects = try context.fetch(FetchDescriptor<ClientProject>())
        sessions = try context.fetch(FetchDescriptor<WorkSession>())
        #expect(projects.isEmpty)
        #expect(sessions.isEmpty)
    }

    private func expectTrackingError(
        _ expected: TrackingManagerError,
        operation: () throws -> Void
    ) throws {
        do {
            try operation()
            Issue.record("Expected error \(expected), but operation succeeded.")
        } catch let error as TrackingManagerError {
            #expect(error == expected)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}

@Suite("TrackingStatusStore")
@MainActor
struct TrackingStatusStoreTests {
    @Test("refresh resets status when there is no active session")
    func refreshWithoutActiveSession() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let store = TrackingStatusStore(modelContainer: container)

        store.refresh()

        #expect(store.activeSession == nil)
        #expect(store.isTracking == false)
        #expect(store.menuBarDurationText == "0:00")
    }

    @Test("refresh publishes active project details and running duration")
    func refreshWithActiveSession() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let project = ClientProject(clientName: "  Kunde A ", name: "  Projekt X ")
        let startedAt = Date(timeIntervalSince1970: 1_000_000)
        let session = WorkSession(project: project, startedAt: startedAt)
        context.insert(project)
        context.insert(session)
        try context.save()

        let store = TrackingStatusStore(modelContainer: container)
        store.refresh()

        let snapshot = try #require(store.activeSession)
        #expect(snapshot.projectName == "Projekt X")
        #expect(snapshot.clientName == "Kunde A")
        #expect(snapshot.startedAt == startedAt)
        #expect(store.isTracking)
        #expect(store.menuBarDurationText.contains(":"))
        #expect(store.menuBarDurationText != "0:00")
    }

    @Test("refresh ignores orphaned active sessions without project")
    func refreshWithOrphanedSession() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let project = ClientProject(clientName: "A", name: "B")
        let session = WorkSession(project: project, startedAt: Date(timeIntervalSince1970: 100))
        session.project = nil
        context.insert(session)
        try context.save()

        let store = TrackingStatusStore(modelContainer: container)
        store.refresh()

        #expect(store.activeSession == nil)
        #expect(store.isTracking == false)
    }
}
