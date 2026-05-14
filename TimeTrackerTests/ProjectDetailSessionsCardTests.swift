import Foundation
import Testing
@testable import TimeTracker

@Suite("Project Detail Sessions Card")
@MainActor
struct ProjectDetailSessionsCardTests {
    private func makeViewModel(
        project: ClientProject,
        activeSession: WorkSession? = nil
    ) -> ProjectDetailViewModel {
        ProjectDetailViewModel(project: project, activeSession: activeSession)
    }

    @Test("Session pending deletion starts nil and clears via binding")
    func sessionPendingDeletionState() {
        let project = ClientProject(clientName: "Acme", name: "Website")
        let session = WorkSession(
            project: project,
            startedAt: .now.addingTimeInterval(-3_600),
            endedAt: .now
        )
        project.sessions = [session]
        let vm = makeViewModel(project: project)

        #expect(vm.sessionPendingDeletion == nil)
        #expect(vm.sessionDeletionIsPresented.wrappedValue == false)

        vm.sessionPendingDeletion = session
        #expect(vm.sessionPendingDeletion?.id == session.id)
        #expect(vm.sessionDeletionIsPresented.wrappedValue == true)

        vm.sessionDeletionIsPresented.wrappedValue = false
        #expect(vm.sessionPendingDeletion == nil)
    }

    @Test("Session pending task creation starts nil and can be set")
    func sessionPendingTaskCreationState() {
        let project = ClientProject(clientName: "Acme", name: "Website")
        let session = WorkSession(
            project: project,
            startedAt: .now.addingTimeInterval(-3_600),
            endedAt: .now
        )
        project.sessions = [session]
        let vm = makeViewModel(project: project)

        #expect(vm.sessionPendingTaskCreation == nil)

        vm.sessionPendingTaskCreation = session
        #expect(vm.sessionPendingTaskCreation?.id == session.id)

        vm.sessionPendingTaskCreation = nil
        #expect(vm.sessionPendingTaskCreation == nil)
    }
}
