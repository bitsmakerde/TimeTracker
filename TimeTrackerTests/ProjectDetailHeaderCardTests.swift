import Foundation
import Testing
@testable import TimeTracker

@Suite("Project Detail Header Card")
@MainActor
struct ProjectDetailHeaderCardTests {
    private func makeViewModel(
        project: ClientProject,
        activeSession: WorkSession? = nil
    ) -> ProjectDetailViewModel {
        ProjectDetailViewModel(project: project, activeSession: activeSession)
    }

    @Test("Action metadata follows project and tracking state")
    func actionMetadataFollowsProjectAndTrackingState() {
        let project = ClientProject(clientName: "Acme", name: "Website")
        let activeSession = WorkSession(project: project, startedAt: .now)
        let archivedProject = ClientProject(clientName: "Acme", name: "Archive", archivedAt: .now)

        let idleVM = makeViewModel(project: project)
        #expect(idleVM.actionButtonTitle == "Zeiterfassung starten")
        #expect(idleVM.actionButtonSystemImage == "play.fill")

        let activeVM = makeViewModel(project: project, activeSession: activeSession)
        #expect(activeVM.actionButtonTitle == "Zeiterfassung stoppen")
        #expect(activeVM.actionButtonSystemImage == "stop.fill")
        #expect(activeVM.isActiveProject)
        #expect(activeVM.isProjectRunningWithoutTask)

        let archivedVM = makeViewModel(project: archivedProject)
        #expect(archivedVM.actionButtonTitle == "Projekt reaktivieren")
        #expect(archivedVM.actionButtonSystemImage == "arrow.uturn.backward.circle.fill")
    }
}
