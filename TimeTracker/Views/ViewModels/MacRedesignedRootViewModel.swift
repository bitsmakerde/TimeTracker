import Foundation
import Observation

@MainActor
@Observable
final class MacRedesignedRootViewModel {
    var selectedProjectID: UUID?
    var search: String = ""
    var presentingNewProject = false
    var manualEntryProject: ClientProject?
    var sessionToEdit: WorkSession?
    var taskToEdit: ProjectTask?
    var errorMessage: String?

    var errorIsPresented: Bool {
        get { errorMessage != nil }
        set {
            if newValue == false {
                errorMessage = nil
            }
        }
    }

    func activeProjects(from projects: [ClientProject]) -> [ClientProject] {
        projects.filter { !$0.isArchived }
    }

    func activeSession(from activeSessions: [WorkSession]) -> WorkSession? {
        activeSessions.first
    }

    func selectedProject(
        from projects: [ClientProject],
        activeSession: WorkSession?
    ) -> ClientProject? {
        let activeProjects = activeProjects(from: projects)
        if let selectedProjectID,
           let selectedProject = activeProjects.first(where: { $0.id == selectedProjectID }) {
            return selectedProject
        }

        return activeSession?.project ?? activeProjects.first
    }

    func selectCreatedProject(_ project: ClientProject) {
        selectedProjectID = project.id
    }

    func clearTaskEditorIfNeeded(deletedTaskID: UUID) {
        if taskToEdit?.id == deletedTaskID {
            taskToEdit = nil
        }
    }
}
