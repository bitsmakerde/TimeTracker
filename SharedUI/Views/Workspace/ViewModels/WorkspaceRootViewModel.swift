import Foundation
import Observation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class WorkspaceRootViewModel {
    var selectedProjectID: UUID?
    var selectedWorkspaceSection: WorkspaceSection = .tracking
    var isPresentingNewProjectSheet = false
    var isPresentingManualSessionSheet = false
    var sessionEditor: SessionEditor?
    var initialClientNameForNewProject = ""
    var errorMessage: String?

    var isPresentingError: Bool {
        get { errorMessage != nil }
        set {
            if !newValue {
                errorMessage = nil
            }
        }
    }

    func activeSession(from activeSessions: [WorkSession]) -> WorkSession? {
        activeSessions.first
    }

    func activeWorkspaceSection(forcedWorkspaceSection: WorkspaceSection?) -> WorkspaceSection {
        forcedWorkspaceSection ?? selectedWorkspaceSection
    }

    func activeProjects(from projects: [ClientProject]) -> [ClientProject] {
        projects.filter { !$0.isArchived }
    }

    func archivedProjects(from projects: [ClientProject]) -> [ClientProject] {
        projects
            .filter(\.isArchived)
            .sorted { lhs, rhs in
                let lhsArchivedAt = lhs.archivedAt ?? .distantPast
                let rhsArchivedAt = rhs.archivedAt ?? .distantPast

                if lhsArchivedAt == rhsArchivedAt {
                    let clientComparison = lhs.displayClientName.localizedCaseInsensitiveCompare(rhs.displayClientName)

                    if clientComparison == .orderedSame {
                        return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
                    }

                    return clientComparison == .orderedAscending
                }

                return lhsArchivedAt > rhsArchivedAt
            }
    }

    func groupedProjects(from projects: [ClientProject]) -> [ClientGroup] {
        Dictionary(grouping: activeProjects(from: projects), by: \.displayClientName)
            .map { key, value in
                ClientGroup(
                    displayName: key,
                    rawClientName: value.first?.clientName.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                    projects: value.sorted {
                        $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                    }
                )
            }
            .sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
    }

    func selectedProject(in projects: [ClientProject]) -> ClientProject? {
        guard let selectedProjectID else {
            return projects.first
        }

        return projects.first { $0.id == selectedProjectID }
    }

    func projectIDList(from projects: [ClientProject]) -> [UUID] {
        projects.map(\.id)
    }

    func ensureInitialSelection(projects: [ClientProject]) {
        if selectedProjectID == nil {
            selectedProjectID = projects.first?.id
        }
    }

    func synchronizeSelection(with projectIDs: [UUID]) {
        if let selectedProjectID,
           !projectIDs.contains(selectedProjectID) {
            self.selectedProjectID = projectIDs.first
            return
        }

        if selectedProjectID == nil {
            selectedProjectID = projectIDs.first
        }
    }

    func selectProject(_ project: ClientProject) {
        selectedProjectID = project.id
    }

    func presentNewProjectSheet(for clientName: String = "") {
        initialClientNameForNewProject = clientName
        isPresentingNewProjectSheet = true
    }

    func presentManualSessionSheet() {
        isPresentingManualSessionSheet = true
    }

    func editSession(_ session: WorkSession, project: ClientProject) {
        sessionEditor = SessionEditor(project: project, session: session)
    }

    func saveNewProject(_ project: ClientProject, in modelContext: ModelContext) -> Bool {
        modelContext.insert(project)

        do {
            try modelContext.save()
            selectedProjectID = project.id
            return true
        } catch {
            modelContext.delete(project)
            errorMessage = "Das Projekt konnte nicht gespeichert werden."
            return false
        }
    }

    func startTracking(
        _ project: ClientProject,
        task: ProjectTask? = nil,
        dependencies: AppDependencies,
        modelContext: ModelContext,
        trackingStatus: TrackingStatusStore
    ) {
        do {
            try dependencies.workspaceTrackingUseCases.startTracking(
                project: project,
                task: task,
                in: modelContext,
                at: .now
            )
            trackingStatus.refresh()
        } catch let trackingError as TrackingManagerError {
            errorMessage = trackingError.errorDescription
        } catch {
            errorMessage = "Die Zeiterfassung fuer dieses Projekt konnte nicht gestartet werden."
        }
    }

    func stopActiveTracking(
        dependencies: AppDependencies,
        modelContext: ModelContext,
        trackingStatus: TrackingStatusStore
    ) {
        do {
            try dependencies.workspaceTrackingUseCases.stopActiveTracking(
                in: modelContext,
                at: .now
            )
            trackingStatus.refresh()
        } catch {
            errorMessage = "Die laufende Zeiterfassung konnte nicht beendet werden."
        }
    }

    func addManualSession(
        for project: ClientProject,
        task: ProjectTask?,
        startedAt: Date,
        endedAt: Date,
        dependencies: AppDependencies,
        modelContext: ModelContext
    ) -> Bool {
        do {
            try dependencies.workspaceTrackingUseCases.addManualSession(
                for: project,
                task: task,
                startedAt: startedAt,
                endedAt: endedAt,
                in: modelContext,
                now: .now
            )
            return true
        } catch let trackingError as TrackingManagerError {
            errorMessage = trackingError.errorDescription
            return false
        } catch {
            errorMessage = "Der Zeiteintrag konnte nicht gespeichert werden."
            return false
        }
    }

    func updateManualSession(
        _ session: WorkSession,
        task: ProjectTask?,
        startedAt: Date,
        endedAt: Date,
        dependencies: AppDependencies,
        modelContext: ModelContext
    ) -> Bool {
        do {
            try dependencies.workspaceTrackingUseCases.updateManualSession(
                session,
                task: task,
                startedAt: startedAt,
                endedAt: endedAt,
                in: modelContext,
                now: .now
            )
            return true
        } catch let trackingError as TrackingManagerError {
            errorMessage = trackingError.errorDescription
            return false
        } catch {
            errorMessage = "Der Zeiteintrag konnte nicht aktualisiert werden."
            return false
        }
    }

    func deleteSession(
        _ session: WorkSession,
        dependencies: AppDependencies,
        modelContext: ModelContext,
        trackingStatus: TrackingStatusStore
    ) {
        do {
            try dependencies.workspaceTrackingUseCases.deleteSession(
                session,
                in: modelContext
            )

            if sessionEditor?.session.id == session.id {
                sessionEditor = nil
            }

            trackingStatus.refresh()
        } catch {
            errorMessage = "Der Zeiteintrag konnte nicht geloescht werden."
        }
    }

    func archiveProject(
        _ project: ClientProject,
        dependencies: AppDependencies,
        modelContext: ModelContext,
        trackingStatus: TrackingStatusStore
    ) {
        do {
            try dependencies.workspaceTrackingUseCases.archiveProject(
                project,
                in: modelContext,
                at: .now
            )
            trackingStatus.refresh()
        } catch let trackingError as TrackingManagerError {
            errorMessage = trackingError.errorDescription
        } catch {
            errorMessage = "Das Projekt konnte nicht archiviert werden."
        }
    }

    func restoreProject(
        _ project: ClientProject,
        dependencies: AppDependencies,
        modelContext: ModelContext,
        trackingStatus: TrackingStatusStore
    ) {
        do {
            try dependencies.workspaceTrackingUseCases.restoreProject(
                project,
                in: modelContext
            )
            trackingStatus.refresh()
        } catch {
            errorMessage = "Das Projekt konnte nicht reaktiviert werden."
        }
    }

    func deleteProject(
        _ project: ClientProject,
        dependencies: AppDependencies,
        modelContext: ModelContext,
        trackingStatus: TrackingStatusStore
    ) {
        let deletedProjectID = project.id

        do {
            try dependencies.workspaceTrackingUseCases.deleteProject(
                project,
                in: modelContext
            )

            if selectedProjectID == deletedProjectID {
                selectedProjectID = nil
            }

            trackingStatus.refresh()
        } catch {
            errorMessage = "Das Projekt konnte nicht geloescht werden."
        }
    }
}


