import Foundation
import Testing
@testable import TimeTracker

@Suite("Project Detail Tasks Card")
@MainActor
struct ProjectDetailTasksCardTests {
    private func makeViewModel(
        project: ClientProject,
        activeSession: WorkSession? = nil
    ) -> ProjectDetailViewModel {
        ProjectDetailViewModel(project: project, activeSession: activeSession)
    }

    @Test("Task duration and value aggregate by task")
    func taskDurationAndValueAggregateByTask() {
        let referenceDate = Date(timeIntervalSince1970: 20_000)
        let project = ClientProject(clientName: "Acme", name: "Website", hourlyRate: 120)
        let designTask = ProjectTask(title: "Design", project: project)
        let buildTask = ProjectTask(title: "Build", project: project)
        project.tasks = [designTask, buildTask]
        project.sessions = [
            WorkSession(
                project: project,
                task: designTask,
                startedAt: referenceDate.addingTimeInterval(-7_200),
                endedAt: referenceDate.addingTimeInterval(-5_400)
            ),
            WorkSession(
                project: project,
                task: designTask,
                startedAt: referenceDate.addingTimeInterval(-3_600),
                endedAt: nil
            ),
            WorkSession(
                project: project,
                task: buildTask,
                startedAt: referenceDate.addingTimeInterval(-1_800),
                endedAt: referenceDate
            ),
        ]
        let vm = makeViewModel(project: project)

        #expect(vm.taskSessionCount(for: designTask) == 2)
        #expect(vm.taskDuration(for: designTask, referenceDate: referenceDate) == 5_400)
        #expect(vm.taskDuration(for: buildTask, referenceDate: referenceDate) == 1_800)
        #expect(vm.taskValueText(for: designTask, referenceDate: referenceDate) == TimeFormatting.euroAmount(180))
    }
}
