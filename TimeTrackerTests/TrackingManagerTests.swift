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

@Suite("Tracking abstractions")
@MainActor
struct TrackingAbstractionTests {
    @Test("SwiftDataTrackingRepository forwards every operation")
    func swiftDataRepositoryForwardsOperations() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let project = ClientProject(clientName: "A", name: "Project")
        let task = ProjectTask(title: "Task", project: project)
        let session = WorkSession(
            project: project,
            task: task,
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 200)
        )
        let spy = TrackingManagerProtocolSpy()
        let repository = SwiftDataTrackingRepository(trackingManager: spy)
        let start = Date(timeIntervalSince1970: 1_000)
        let end = Date(timeIntervalSince1970: 2_000)
        let now = Date(timeIntervalSince1970: 3_000)
        let archiveDate = Date(timeIntervalSince1970: 4_000)

        try repository.startTracking(
            project: project,
            task: task,
            in: context,
            at: start
        )
        try repository.stopActiveTracking(in: context, at: end)
        try repository.addManualSession(
            for: project,
            task: task,
            startedAt: start,
            endedAt: end,
            in: context,
            now: now
        )
        try repository.updateManualSession(
            session,
            task: task,
            startedAt: start,
            endedAt: end,
            in: context,
            now: now
        )
        try repository.archiveProject(project, in: context, at: archiveDate)
        try repository.restoreProject(project, in: context)
        try repository.deleteProject(project, in: context)
        try repository.deleteSession(session, in: context)

        let expectedCalls: [TrackingOperationCall] = [
            .start(projectID: project.id, taskID: task.id, referenceDate: start),
            .stop(referenceDate: end),
            .add(projectID: project.id, taskID: task.id, startedAt: start, endedAt: end, now: now),
            .update(sessionID: session.id, taskID: task.id, startedAt: start, endedAt: end, now: now),
            .archive(projectID: project.id, referenceDate: archiveDate),
            .restore(projectID: project.id),
            .deleteProject(projectID: project.id),
            .deleteSession(sessionID: session.id),
        ]
        #expect(spy.calls == expectedCalls)
    }

    @Test("DefaultWorkspaceTrackingUseCases forwards every operation")
    func workspaceTrackingUseCasesForwardOperations() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let project = ClientProject(clientName: "A", name: "Project")
        let task = ProjectTask(title: "Task", project: project)
        let session = WorkSession(
            project: project,
            task: task,
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 200)
        )
        let spy = TrackingRepositoryProtocolSpy()
        let useCases = DefaultWorkspaceTrackingUseCases(repository: spy)
        let start = Date(timeIntervalSince1970: 1_000)
        let end = Date(timeIntervalSince1970: 2_000)
        let now = Date(timeIntervalSince1970: 3_000)
        let archiveDate = Date(timeIntervalSince1970: 4_000)

        try useCases.startTracking(
            project: project,
            task: task,
            in: context,
            at: start
        )
        try useCases.stopActiveTracking(in: context, at: end)
        try useCases.addManualSession(
            for: project,
            task: task,
            startedAt: start,
            endedAt: end,
            in: context,
            now: now
        )
        try useCases.updateManualSession(
            session,
            task: task,
            startedAt: start,
            endedAt: end,
            in: context,
            now: now
        )
        try useCases.archiveProject(project, in: context, at: archiveDate)
        try useCases.restoreProject(project, in: context)
        try useCases.deleteProject(project, in: context)
        try useCases.deleteSession(session, in: context)

        let expectedCalls: [TrackingOperationCall] = [
            .start(projectID: project.id, taskID: task.id, referenceDate: start),
            .stop(referenceDate: end),
            .add(projectID: project.id, taskID: task.id, startedAt: start, endedAt: end, now: now),
            .update(sessionID: session.id, taskID: task.id, startedAt: start, endedAt: end, now: now),
            .archive(projectID: project.id, referenceDate: archiveDate),
            .restore(projectID: project.id),
            .deleteProject(projectID: project.id),
            .deleteSession(sessionID: session.id),
        ]
        #expect(spy.calls == expectedCalls)
    }
}

@Suite("WorkspaceRootViewModel actions")
@MainActor
struct WorkspaceRootViewModelActionTests {
    @Test("collection helpers sort archived ties and grouped project names predictably")
    func collectionHelpersSortArchivedAndActiveProjects() {
        let archivedAt = Date(timeIntervalSince1970: 500)
        let archivedBeta = ClientProject(clientName: "Beta", name: "Alpha", archivedAt: archivedAt)
        let archivedAlphaZulu = ClientProject(clientName: "Alpha", name: "Zulu", archivedAt: archivedAt)
        let archivedAlphaEcho = ClientProject(clientName: "Alpha", name: "Echo", archivedAt: archivedAt)
        let activeZeta = ClientProject(clientName: "  Acme  ", name: "Zeta")
        let activeAlpha = ClientProject(clientName: "Acme", name: "Alpha")
        let activeSession = WorkSession(project: activeZeta, startedAt: Date(timeIntervalSince1970: 100))
        let viewModel = WorkspaceRootViewModel()

        #expect(viewModel.activeSession(from: [activeSession])?.id == activeSession.id)
        #expect(
            viewModel.activeProjects(
                from: [archivedBeta, activeZeta, archivedAlphaZulu, activeAlpha]
            ).map(\.displayName) == ["Zeta", "Alpha"]
        )

        let groups = viewModel.groupedProjects(from: [activeZeta, activeAlpha])
        #expect(groups.count == 1)
        #expect(groups.first?.displayName == "Acme")
        #expect(groups.first?.rawClientName == "Acme")
        #expect(groups.first?.projects.map(\.displayName) == ["Alpha", "Zeta"])

        let archivedProjects = viewModel.archivedProjects(
            from: [archivedBeta, archivedAlphaZulu, archivedAlphaEcho]
        )
        #expect(archivedProjects.map(\.displayName) == ["Echo", "Zulu", "Alpha"])
    }

    @Test("presentation helpers and selected project lookup update state")
    func presentationAndSelectionState() {
        let firstProject = ClientProject(clientName: "Alpha", name: "One")
        let secondProject = ClientProject(clientName: "Beta", name: "Two")
        let session = WorkSession(project: secondProject)
        let viewModel = WorkspaceRootViewModel()

        #expect(viewModel.selectedProject(in: [firstProject, secondProject])?.id == firstProject.id)
        #expect(viewModel.activeWorkspaceSection(forcedWorkspaceSection: nil) == .tracking)
        #expect(viewModel.activeWorkspaceSection(forcedWorkspaceSection: .analytics) == .analytics)
        #expect(viewModel.projectIDList(from: [firstProject, secondProject]) == [firstProject.id, secondProject.id])

        viewModel.selectProject(secondProject)
        #expect(viewModel.selectedProject(in: [firstProject, secondProject])?.id == secondProject.id)

        viewModel.presentNewProjectSheet(for: "Neuer Kunde")
        #expect(viewModel.initialClientNameForNewProject == "Neuer Kunde")
        #expect(viewModel.isPresentingNewProjectSheet)

        viewModel.presentManualSessionSheet()
        #expect(viewModel.isPresentingManualSessionSheet)

        viewModel.editSession(session, project: secondProject)
        #expect(viewModel.sessionEditor?.id == session.id)

        viewModel.errorMessage = "Fehler"
        #expect(viewModel.isPresentingError)
        viewModel.isPresentingError = false
        #expect(viewModel.errorMessage == nil)
    }

    @Test("saveNewProject persists and selects the new project")
    func saveNewProjectPersistsAndSelectsProject() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let project = ClientProject(clientName: "A", name: "Saved")
        let viewModel = WorkspaceRootViewModel()

        let didSave = viewModel.saveNewProject(project, in: context)
        let projects = try context.fetch(FetchDescriptor<ClientProject>())

        #expect(didSave)
        #expect(projects.map(\.id) == [project.id])
        #expect(viewModel.selectedProjectID == project.id)
    }

    @Test("tracking actions call dependencies and maintain local state")
    func trackingActionsCallDependencies() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let trackingStatus = TrackingStatusStore(
            modelContainer: container,
            crossDeviceChannel: NoopCrossDeviceTrackingChannel()
        )
        let project = ClientProject(clientName: "A", name: "Project")
        let task = ProjectTask(title: "Task", project: project)
        let session = WorkSession(
            project: project,
            task: task,
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 200)
        )
        let spy = WorkspaceTrackingUseCasesProtocolSpy()
        let dependencies = AppDependencies(
            configuration: TimeTrackerTargetConfiguration.macOS,
            workspaceTrackingUseCases: spy
        )
        let viewModel = WorkspaceRootViewModel()
        viewModel.selectedProjectID = project.id
        viewModel.sessionEditor = SessionEditor(project: project, session: session)

        viewModel.startTracking(
            project,
            task: task,
            dependencies: dependencies,
            modelContext: context,
            trackingStatus: trackingStatus
        )
        viewModel.stopActiveTracking(
            dependencies: dependencies,
            modelContext: context,
            trackingStatus: trackingStatus
        )
        let didAdd = viewModel.addManualSession(
            for: project,
            task: task,
            startedAt: Date(timeIntervalSince1970: 1_000),
            endedAt: Date(timeIntervalSince1970: 2_000),
            dependencies: dependencies,
            modelContext: context
        )
        let didUpdate = viewModel.updateManualSession(
            session,
            task: task,
            startedAt: Date(timeIntervalSince1970: 1_000),
            endedAt: Date(timeIntervalSince1970: 2_000),
            dependencies: dependencies,
            modelContext: context
        )
        viewModel.deleteSession(
            session,
            dependencies: dependencies,
            modelContext: context,
            trackingStatus: trackingStatus
        )
        viewModel.archiveProject(
            project,
            dependencies: dependencies,
            modelContext: context,
            trackingStatus: trackingStatus
        )
        viewModel.restoreProject(
            project,
            dependencies: dependencies,
            modelContext: context,
            trackingStatus: trackingStatus
        )
        viewModel.deleteProject(
            project,
            dependencies: dependencies,
            modelContext: context,
            trackingStatus: trackingStatus
        )

        #expect(didAdd)
        #expect(didUpdate)
        #expect(
            spy.calls.map(\.kind) == [
                .start,
                .stop,
                .add,
                .update,
                .deleteSession,
                .archive,
                .restore,
                .deleteProject,
            ]
        )
        #expect(viewModel.sessionEditor == nil)
        #expect(viewModel.selectedProjectID == nil)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("tracking action errors expose user-facing messages")
    func trackingActionErrorsExposeMessages() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let trackingStatus = TrackingStatusStore(
            modelContainer: container,
            crossDeviceChannel: NoopCrossDeviceTrackingChannel()
        )
        let project = ClientProject(clientName: "A", name: "Project")
        let spy = WorkspaceTrackingUseCasesProtocolSpy()
        let dependencies = AppDependencies(
            configuration: TimeTrackerTargetConfiguration.macOS,
            workspaceTrackingUseCases: spy
        )
        let viewModel = WorkspaceRootViewModel()

        spy.errorToThrow = TrackingManagerError.archivedProjectNotEditable
        viewModel.startTracking(
            project,
            dependencies: dependencies,
            modelContext: context,
            trackingStatus: trackingStatus
        )
        #expect(viewModel.errorMessage == TrackingManagerError.archivedProjectNotEditable.errorDescription)

        viewModel.isPresentingError = false
        spy.errorToThrow = WorkspaceTrackingUseCasesProtocolSpy.Failure()
        let didAdd = viewModel.addManualSession(
            for: project,
            task: nil,
            startedAt: Date(timeIntervalSince1970: 1_000),
            endedAt: Date(timeIntervalSince1970: 2_000),
            dependencies: dependencies,
            modelContext: context
        )

        #expect(didAdd == false)
        #expect(viewModel.errorMessage == "Der Zeiteintrag konnte nicht gespeichert werden.")
    }

    @Test("tracking action fallback errors cover remaining user-facing messages")
    func trackingActionFallbackErrorsExposeMessages() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let trackingStatus = TrackingStatusStore(
            modelContainer: container,
            crossDeviceChannel: NoopCrossDeviceTrackingChannel()
        )
        let project = ClientProject(clientName: "A", name: "Project")
        let session = WorkSession(
            project: project,
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 200)
        )
        let spy = WorkspaceTrackingUseCasesProtocolSpy()
        let dependencies = AppDependencies(
            configuration: TimeTrackerTargetConfiguration.macOS,
            workspaceTrackingUseCases: spy
        )
        let viewModel = WorkspaceRootViewModel()

        spy.errorToThrow = WorkspaceTrackingUseCasesProtocolSpy.Failure()
        viewModel.stopActiveTracking(
            dependencies: dependencies,
            modelContext: context,
            trackingStatus: trackingStatus
        )
        #expect(viewModel.errorMessage == "Die laufende Zeiterfassung konnte nicht beendet werden.")

        viewModel.isPresentingError = false
        let didUpdate = viewModel.updateManualSession(
            session,
            task: nil,
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 200),
            dependencies: dependencies,
            modelContext: context
        )
        #expect(didUpdate == false)
        #expect(viewModel.errorMessage == "Der Zeiteintrag konnte nicht aktualisiert werden.")

        viewModel.isPresentingError = false
        viewModel.deleteSession(
            session,
            dependencies: dependencies,
            modelContext: context,
            trackingStatus: trackingStatus
        )
        #expect(viewModel.errorMessage == "Der Zeiteintrag konnte nicht geloescht werden.")

        viewModel.isPresentingError = false
        viewModel.archiveProject(
            project,
            dependencies: dependencies,
            modelContext: context,
            trackingStatus: trackingStatus
        )
        #expect(viewModel.errorMessage == "Das Projekt konnte nicht archiviert werden.")

        viewModel.isPresentingError = false
        viewModel.restoreProject(
            project,
            dependencies: dependencies,
            modelContext: context,
            trackingStatus: trackingStatus
        )
        #expect(viewModel.errorMessage == "Das Projekt konnte nicht reaktiviert werden.")

        viewModel.isPresentingError = false
        viewModel.deleteProject(
            project,
            dependencies: dependencies,
            modelContext: context,
            trackingStatus: trackingStatus
        )
        #expect(viewModel.errorMessage == "Das Projekt konnte nicht geloescht werden.")
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

    @Test("cloud sync status starts as waiting when CloudKit mode is enabled")
    func cloudSyncStartsWaiting() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let store = TrackingStatusStore(
            modelContainer: container,
            syncMode: .cloudKitPrivate(containerIdentifier: "iCloud.de.bitsmaker.TimeTracker")
        )

        #expect(store.syncStatus == .waitingForCloud)
    }

    @Test("cloud sync status starts as local only when CloudKit is disabled")
    func cloudSyncStartsLocalOnly() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let store = TrackingStatusStore(
            modelContainer: container,
            syncMode: .localOnly
        )

        #expect(store.syncStatus == .localOnly)
    }

    @Test("sync status changes to syncing while an export event is in progress")
    func syncStatusChangesToRunning() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let store = TrackingStatusStore(
            modelContainer: container,
            syncMode: .cloudKitPrivate(containerIdentifier: "iCloud.de.bitsmaker.TimeTracker")
        )
        let startedAt = Date(timeIntervalSince1970: 1_000)

        store.handleCloudKitEvent(
            CloudKitSyncEventSnapshot(
                eventType: .export,
                startDate: startedAt,
                endDate: nil,
                succeeded: false,
                errorDescription: nil
            )
        )

        #expect(store.syncStatus == .syncing(operation: .export, startedAt: startedAt))
    }

    @Test("successful import and export events update latest sync timestamps")
    func syncStatusTracksSuccessfulEvents() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let store = TrackingStatusStore(
            modelContainer: container,
            syncMode: .cloudKitPrivate(containerIdentifier: "iCloud.de.bitsmaker.TimeTracker")
        )
        let importEnd = Date(timeIntervalSince1970: 2_000)
        let exportEnd = Date(timeIntervalSince1970: 3_000)

        store.handleCloudKitEvent(
            CloudKitSyncEventSnapshot(
                eventType: .importData,
                startDate: Date(timeIntervalSince1970: 1_900),
                endDate: importEnd,
                succeeded: true,
                errorDescription: nil
            )
        )
        store.handleCloudKitEvent(
            CloudKitSyncEventSnapshot(
                eventType: .export,
                startDate: Date(timeIntervalSince1970: 2_900),
                endDate: exportEnd,
                succeeded: true,
                errorDescription: nil
            )
        )

        #expect(store.lastSuccessfulImportAt == importEnd)
        #expect(store.lastSuccessfulExportAt == exportEnd)
        #expect(store.syncStatus == .upToDate(lastSyncAt: exportEnd))
    }

    @Test("failed cloud event sets failed sync status with message")
    func syncStatusTracksFailure() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let store = TrackingStatusStore(
            modelContainer: container,
            syncMode: .cloudKitPrivate(containerIdentifier: "iCloud.de.bitsmaker.TimeTracker")
        )
        let endDate = Date(timeIntervalSince1970: 4_000)
        let errorMessage = "Invalid bundle ID for container"

        store.handleCloudKitEvent(
            CloudKitSyncEventSnapshot(
                eventType: .setup,
                startDate: Date(timeIntervalSince1970: 3_900),
                endDate: endDate,
                succeeded: false,
                errorDescription: errorMessage
            )
        )

        #expect(store.syncStatus == .failed(message: errorMessage, at: endDate))
        #expect(store.lastSyncErrorMessage == errorMessage)
    }

    @Test("refresh publishes realtime start details to cross-device channel")
    func refreshPublishesRealtimeStartDetails() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let project = ClientProject(clientName: "Kunde A", name: "Projekt X")
        let task = ProjectTask(title: "Bugfix", project: project)
        let startedAt = Date(timeIntervalSince1970: 5_000)
        let session = WorkSession(project: project, task: task, startedAt: startedAt)

        context.insert(project)
        context.insert(task)
        context.insert(session)
        try context.save()

        let channel = CrossDeviceTrackingChannelSpy()
        _ = TrackingStatusStore(
            modelContainer: container,
            syncMode: .cloudKitPrivate(containerIdentifier: "iCloud.de.bitsmaker.TimeTracker"),
            crossDeviceChannel: channel,
            deviceID: "device-a"
        )

        let publishedSnapshot = try #require(channel.publishedSnapshots.last)
        #expect(publishedSnapshot.lifecycle == .started)
        #expect(publishedSnapshot.projectName == "Projekt X")
        #expect(publishedSnapshot.clientName == "Kunde A")
        #expect(publishedSnapshot.taskTitle == "Bugfix")
        #expect(publishedSnapshot.startedAt == startedAt)
    }

    @Test("refresh publishes realtime stop when active tracking ends")
    func refreshPublishesRealtimeStop() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let project = ClientProject(clientName: "Kunde A", name: "Projekt X")
        let startedAt = Date(timeIntervalSince1970: 6_000)
        let session = WorkSession(project: project, startedAt: startedAt)

        context.insert(project)
        context.insert(session)
        try context.save()

        let channel = CrossDeviceTrackingChannelSpy()
        let store = TrackingStatusStore(
            modelContainer: container,
            syncMode: .cloudKitPrivate(containerIdentifier: "iCloud.de.bitsmaker.TimeTracker"),
            crossDeviceChannel: channel,
            deviceID: "device-a"
        )

        session.endedAt = Date(timeIntervalSince1970: 6_600)
        try context.save()
        store.refresh()

        let publishedSnapshot = try #require(channel.publishedSnapshots.last)
        #expect(publishedSnapshot.lifecycle == .stopped)
        #expect(publishedSnapshot.projectName == "Projekt X")
        #expect(publishedSnapshot.taskTitle == "Ohne Aufgabe")
    }

    @Test("cross-device snapshots from other devices are exposed")
    func crossDeviceSnapshotIsExposed() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let channel = CrossDeviceTrackingChannelSpy()
        let store = TrackingStatusStore(
            modelContainer: container,
            syncMode: .cloudKitPrivate(containerIdentifier: "iCloud.de.bitsmaker.TimeTracker"),
            crossDeviceChannel: channel,
            deviceID: "device-a"
        )

        let remoteSnapshot = CrossDeviceTrackingSnapshot(
            sourceDeviceID: "device-b",
            projectName: "Projekt B",
            clientName: "Kunde B",
            taskTitle: "Implementierung",
            startedAt: Date(timeIntervalSince1970: 7_000),
            lifecycle: .started,
            updatedAt: Date(timeIntervalSince1970: 7_001)
        )

        channel.emitIncomingSnapshot(remoteSnapshot)

        #expect(store.crossDeviceTrackingSnapshot == remoteSnapshot)
    }

    @Test("cross-device snapshots from current device are ignored")
    func crossDeviceSnapshotFromCurrentDeviceIsIgnored() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let channel = CrossDeviceTrackingChannelSpy()
        let store = TrackingStatusStore(
            modelContainer: container,
            syncMode: .cloudKitPrivate(containerIdentifier: "iCloud.de.bitsmaker.TimeTracker"),
            crossDeviceChannel: channel,
            deviceID: "device-a"
        )

        let localEchoSnapshot = CrossDeviceTrackingSnapshot(
            sourceDeviceID: "device-a",
            projectName: "Projekt A",
            clientName: "Kunde A",
            taskTitle: "Design",
            startedAt: Date(timeIntervalSince1970: 8_000),
            lifecycle: .started,
            updatedAt: Date(timeIntervalSince1970: 8_001)
        )

        channel.emitIncomingSnapshot(localEchoSnapshot)

        #expect(store.crossDeviceTrackingSnapshot == nil)
    }

    @Test("cross-device start snapshot updates remote tracking indicator")
    func crossDeviceStartSnapshotUpdatesRemoteTrackingIndicator() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let channel = CrossDeviceTrackingChannelSpy()
        let store = TrackingStatusStore(
            modelContainer: container,
            syncMode: .cloudKitPrivate(containerIdentifier: "iCloud.de.bitsmaker.TimeTracker"),
            crossDeviceChannel: channel,
            deviceID: "device-a"
        )

        channel.emitIncomingSnapshot(
            CrossDeviceTrackingSnapshot(
                sourceDeviceID: "device-b",
                projectName: "Projekt B",
                clientName: "Kunde B",
                taskTitle: "Analyse",
                startedAt: .now.addingTimeInterval(-90),
                lifecycle: .started,
                updatedAt: .now
            )
        )

        #expect(store.isTrackingOnAnotherDevice)
        #expect(store.menuBarCrossDeviceDurationText != nil)
    }

    @Test("cross-device stop snapshot clears remote tracking indicator")
    func crossDeviceStopSnapshotClearsRemoteTrackingIndicator() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let channel = CrossDeviceTrackingChannelSpy()
        let store = TrackingStatusStore(
            modelContainer: container,
            syncMode: .cloudKitPrivate(containerIdentifier: "iCloud.de.bitsmaker.TimeTracker"),
            crossDeviceChannel: channel,
            deviceID: "device-a"
        )
        let startedAt = Date.now.addingTimeInterval(-120)

        channel.emitIncomingSnapshot(
            CrossDeviceTrackingSnapshot(
                sourceDeviceID: "device-b",
                projectName: "Projekt B",
                clientName: "Kunde B",
                taskTitle: "Analyse",
                startedAt: startedAt,
                lifecycle: .started,
                updatedAt: .now
            )
        )
        channel.emitIncomingSnapshot(
            CrossDeviceTrackingSnapshot(
                sourceDeviceID: "device-b",
                projectName: "Projekt B",
                clientName: "Kunde B",
                taskTitle: "Analyse",
                startedAt: startedAt,
                lifecycle: .stopped,
                updatedAt: .now
            )
        )

        #expect(store.isTrackingOnAnotherDevice == false)
        #expect(store.menuBarCrossDeviceDurationText == nil)
    }

    @Test("cross-device stop snapshot hides stale local active session immediately")
    func crossDeviceStopSnapshotHidesStaleLocalActiveSession() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let project = ClientProject(clientName: "Kunde A", name: "Projekt A")
        let startedAt = Date(timeIntervalSince1970: 9_000)
        let session = WorkSession(project: project, startedAt: startedAt)
        context.insert(project)
        context.insert(session)
        try context.save()

        let channel = CrossDeviceTrackingChannelSpy()
        let store = TrackingStatusStore(
            modelContainer: container,
            syncMode: .cloudKitPrivate(containerIdentifier: "iCloud.de.bitsmaker.TimeTracker"),
            crossDeviceChannel: channel,
            deviceID: "device-a"
        )

        #expect(store.activeSession?.startedAt == startedAt)

        channel.emitIncomingSnapshot(
            CrossDeviceTrackingSnapshot(
                sourceDeviceID: "device-b",
                projectName: "Projekt A",
                clientName: "Kunde A",
                taskTitle: "Ohne Aufgabe",
                startedAt: startedAt,
                lifecycle: .stopped,
                updatedAt: .now
            )
        )

        #expect(store.activeSession == nil)
        #expect(store.isTracking == false)
    }

    @Test("local active session returns after remote stop once a new local session exists")
    func localSessionReturnsAfterRemoteStopWhenNewSessionStarts() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let project = ClientProject(clientName: "Kunde A", name: "Projekt A")
        let firstStartedAt = Date(timeIntervalSince1970: 10_000)
        let firstSession = WorkSession(project: project, startedAt: firstStartedAt)
        context.insert(project)
        context.insert(firstSession)
        try context.save()

        let channel = CrossDeviceTrackingChannelSpy()
        let store = TrackingStatusStore(
            modelContainer: container,
            syncMode: .cloudKitPrivate(containerIdentifier: "iCloud.de.bitsmaker.TimeTracker"),
            crossDeviceChannel: channel,
            deviceID: "device-a"
        )

        channel.emitIncomingSnapshot(
            CrossDeviceTrackingSnapshot(
                sourceDeviceID: "device-b",
                projectName: "Projekt A",
                clientName: "Kunde A",
                taskTitle: "Ohne Aufgabe",
                startedAt: firstStartedAt,
                lifecycle: .stopped,
                updatedAt: .now
            )
        )
        #expect(store.activeSession == nil)

        firstSession.endedAt = firstStartedAt
        let secondStartedAt = Date(timeIntervalSince1970: 10_500)
        let secondSession = WorkSession(project: project, startedAt: secondStartedAt)
        context.insert(secondSession)
        try context.save()

        store.refresh()

        #expect(store.activeSession?.startedAt == secondStartedAt)
        #expect(store.isTracking)
    }

    @Test("refresh keeps the oldest active session when conflicts exist")
    func refreshPrefersOldestSessionOnConflict() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let context = container.mainContext

        let oldestProject = ClientProject(clientName: "Kunde A", name: "Aeltestes")
        let newestProject = ClientProject(clientName: "Kunde B", name: "Neuestes")
        let oldestSession = WorkSession(
            project: oldestProject,
            startedAt: Date(timeIntervalSince1970: 100)
        )
        let newestSession = WorkSession(
            project: newestProject,
            startedAt: Date(timeIntervalSince1970: 200)
        )
        context.insert(oldestProject)
        context.insert(newestProject)
        context.insert(oldestSession)
        context.insert(newestSession)
        try context.save()

        let store = TrackingStatusStore(modelContainer: container)
        store.refresh()

        let snapshot = try #require(store.activeSession)
        #expect(snapshot.projectName == oldestProject.displayName)
        #expect(snapshot.clientName == oldestProject.displayClientName)
        #expect(snapshot.startedAt == oldestSession.startedAt)
    }

    @Test("refresh ends newer conflicting sessions with zero duration")
    func refreshEndsNewerConflictsAtStartDate() throws {
        let container = try TestSupport.makeInMemoryContainer()
        let context = container.mainContext

        let project = ClientProject(clientName: "Kunde", name: "Projekt")
        let oldestSession = WorkSession(
            project: project,
            startedAt: Date(timeIntervalSince1970: 100)
        )
        let newerSession = WorkSession(
            project: project,
            startedAt: Date(timeIntervalSince1970: 200)
        )
        let newestSession = WorkSession(
            project: project,
            startedAt: Date(timeIntervalSince1970: 300)
        )

        context.insert(project)
        context.insert(oldestSession)
        context.insert(newerSession)
        context.insert(newestSession)
        try context.save()

        let store = TrackingStatusStore(modelContainer: container)
        store.refresh()

        let sessions = try context.fetch(
            FetchDescriptor<WorkSession>(
                sortBy: [SortDescriptor(\WorkSession.startedAt)]
            )
        )
        let activeSessions = sessions.filter(\.isActive)

        #expect(activeSessions.count == 1)
        #expect(activeSessions.first?.id == oldestSession.id)
        #expect(newerSession.endedAt == newerSession.startedAt)
        #expect(newestSession.endedAt == newestSession.startedAt)
        #expect(newerSession.duration(referenceDate: Date(timeIntervalSince1970: 500)) == 0)
        #expect(newestSession.duration(referenceDate: Date(timeIntervalSince1970: 500)) == 0)
    }
}

@MainActor
private final class CrossDeviceTrackingChannelSpy: CrossDeviceTrackingChannelProtocol {
    private var onChange: ((CrossDeviceTrackingSnapshot?) -> Void)?
    private(set) var publishedSnapshots: [CrossDeviceTrackingSnapshot] = []

    func start(onChange: @escaping (CrossDeviceTrackingSnapshot?) -> Void) {
        self.onChange = onChange
        onChange(nil)
    }

    func publish(_ snapshot: CrossDeviceTrackingSnapshot) {
        publishedSnapshots.append(snapshot)
    }

    func refresh() {}

    func emitIncomingSnapshot(_ snapshot: CrossDeviceTrackingSnapshot?) {
        onChange?(snapshot)
    }
}

private enum TrackingOperationCall: Equatable {
    enum Kind: Equatable {
        case start
        case stop
        case add
        case update
        case archive
        case restore
        case deleteProject
        case deleteSession
    }

    case start(projectID: UUID, taskID: UUID?, referenceDate: Date)
    case stop(referenceDate: Date)
    case add(projectID: UUID, taskID: UUID?, startedAt: Date, endedAt: Date, now: Date)
    case update(sessionID: UUID, taskID: UUID?, startedAt: Date, endedAt: Date, now: Date)
    case archive(projectID: UUID, referenceDate: Date)
    case restore(projectID: UUID)
    case deleteProject(projectID: UUID)
    case deleteSession(sessionID: UUID)

    var kind: Kind {
        switch self {
        case .start:
            return .start
        case .stop:
            return .stop
        case .add:
            return .add
        case .update:
            return .update
        case .archive:
            return .archive
        case .restore:
            return .restore
        case .deleteProject:
            return .deleteProject
        case .deleteSession:
            return .deleteSession
        }
    }
}

private final class TrackingManagerProtocolSpy: TrackingManagerProtocol {
    private(set) var calls: [TrackingOperationCall] = []

    func startTracking(
        project: ClientProject,
        task: ProjectTask?,
        in context: ModelContext,
        at referenceDate: Date
    ) throws {
        calls.append(.start(projectID: project.id, taskID: task?.id, referenceDate: referenceDate))
    }

    func stopActiveTracking(
        in context: ModelContext,
        at referenceDate: Date
    ) throws {
        calls.append(.stop(referenceDate: referenceDate))
    }

    func addManualSession(
        for project: ClientProject,
        task: ProjectTask?,
        startedAt: Date,
        endedAt: Date,
        in context: ModelContext,
        now: Date
    ) throws {
        calls.append(.add(projectID: project.id, taskID: task?.id, startedAt: startedAt, endedAt: endedAt, now: now))
    }

    func updateManualSession(
        _ session: WorkSession,
        task: ProjectTask?,
        startedAt: Date,
        endedAt: Date,
        in context: ModelContext,
        now: Date
    ) throws {
        calls.append(.update(sessionID: session.id, taskID: task?.id, startedAt: startedAt, endedAt: endedAt, now: now))
    }

    func archiveProject(
        _ project: ClientProject,
        in context: ModelContext,
        at referenceDate: Date
    ) throws {
        calls.append(.archive(projectID: project.id, referenceDate: referenceDate))
    }

    func restoreProject(
        _ project: ClientProject,
        in context: ModelContext
    ) throws {
        calls.append(.restore(projectID: project.id))
    }

    func deleteProject(
        _ project: ClientProject,
        in context: ModelContext
    ) throws {
        calls.append(.deleteProject(projectID: project.id))
    }

    func deleteSession(
        _ session: WorkSession,
        in context: ModelContext
    ) throws {
        calls.append(.deleteSession(sessionID: session.id))
    }
}

private final class TrackingRepositoryProtocolSpy: TrackingRepositoryProtocol {
    private(set) var calls: [TrackingOperationCall] = []

    func startTracking(
        project: ClientProject,
        task: ProjectTask?,
        in context: ModelContext,
        at referenceDate: Date
    ) throws {
        calls.append(.start(projectID: project.id, taskID: task?.id, referenceDate: referenceDate))
    }

    func stopActiveTracking(
        in context: ModelContext,
        at referenceDate: Date
    ) throws {
        calls.append(.stop(referenceDate: referenceDate))
    }

    func addManualSession(
        for project: ClientProject,
        task: ProjectTask?,
        startedAt: Date,
        endedAt: Date,
        in context: ModelContext,
        now: Date
    ) throws {
        calls.append(.add(projectID: project.id, taskID: task?.id, startedAt: startedAt, endedAt: endedAt, now: now))
    }

    func updateManualSession(
        _ session: WorkSession,
        task: ProjectTask?,
        startedAt: Date,
        endedAt: Date,
        in context: ModelContext,
        now: Date
    ) throws {
        calls.append(.update(sessionID: session.id, taskID: task?.id, startedAt: startedAt, endedAt: endedAt, now: now))
    }

    func archiveProject(
        _ project: ClientProject,
        in context: ModelContext,
        at referenceDate: Date
    ) throws {
        calls.append(.archive(projectID: project.id, referenceDate: referenceDate))
    }

    func restoreProject(
        _ project: ClientProject,
        in context: ModelContext
    ) throws {
        calls.append(.restore(projectID: project.id))
    }

    func deleteProject(
        _ project: ClientProject,
        in context: ModelContext
    ) throws {
        calls.append(.deleteProject(projectID: project.id))
    }

    func deleteSession(
        _ session: WorkSession,
        in context: ModelContext
    ) throws {
        calls.append(.deleteSession(sessionID: session.id))
    }
}

private final class WorkspaceTrackingUseCasesProtocolSpy: WorkspaceTrackingUseCasesProtocol {
    struct Failure: Error {}

    var errorToThrow: Error?
    private(set) var calls: [TrackingOperationCall] = []

    func startTracking(
        project: ClientProject,
        task: ProjectTask?,
        in context: ModelContext,
        at referenceDate: Date
    ) throws {
        calls.append(.start(projectID: project.id, taskID: task?.id, referenceDate: referenceDate))
        try throwIfNeeded()
    }

    func stopActiveTracking(
        in context: ModelContext,
        at referenceDate: Date
    ) throws {
        calls.append(.stop(referenceDate: referenceDate))
        try throwIfNeeded()
    }

    func addManualSession(
        for project: ClientProject,
        task: ProjectTask?,
        startedAt: Date,
        endedAt: Date,
        in context: ModelContext,
        now: Date
    ) throws {
        calls.append(.add(projectID: project.id, taskID: task?.id, startedAt: startedAt, endedAt: endedAt, now: now))
        try throwIfNeeded()
    }

    func updateManualSession(
        _ session: WorkSession,
        task: ProjectTask?,
        startedAt: Date,
        endedAt: Date,
        in context: ModelContext,
        now: Date
    ) throws {
        calls.append(.update(sessionID: session.id, taskID: task?.id, startedAt: startedAt, endedAt: endedAt, now: now))
        try throwIfNeeded()
    }

    func archiveProject(
        _ project: ClientProject,
        in context: ModelContext,
        at referenceDate: Date
    ) throws {
        calls.append(.archive(projectID: project.id, referenceDate: referenceDate))
        try throwIfNeeded()
    }

    func restoreProject(
        _ project: ClientProject,
        in context: ModelContext
    ) throws {
        calls.append(.restore(projectID: project.id))
        try throwIfNeeded()
    }

    func deleteProject(
        _ project: ClientProject,
        in context: ModelContext
    ) throws {
        calls.append(.deleteProject(projectID: project.id))
        try throwIfNeeded()
    }

    func deleteSession(
        _ session: WorkSession,
        in context: ModelContext
    ) throws {
        calls.append(.deleteSession(sessionID: session.id))
        try throwIfNeeded()
    }

    private func throwIfNeeded() throws {
        if let errorToThrow {
            throw errorToThrow
        }
    }
}
