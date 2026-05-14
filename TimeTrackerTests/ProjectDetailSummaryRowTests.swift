import Foundation
import Testing
@testable import TimeTracker

@Suite("Project Detail Summary Row")
@MainActor
struct ProjectDetailSummaryRowTests {
    private func makeViewModel(
        project: ClientProject,
        activeSession: WorkSession? = nil
    ) -> ProjectDetailViewModel {
        ProjectDetailViewModel(project: project, activeSession: activeSession)
    }

    @Test("Total duration includes ended and active sessions")
    func totalDurationIncludesEndedAndActiveSessions() {
        let referenceDate = Date(timeIntervalSince1970: 10_000)
        let project = ClientProject(clientName: "Acme", name: "Website", hourlyRate: 100)
        project.sessions = [
            WorkSession(
                project: project,
                startedAt: referenceDate.addingTimeInterval(-7_200),
                endedAt: referenceDate.addingTimeInterval(-5_400)
            ),
            WorkSession(
                project: project,
                startedAt: referenceDate.addingTimeInterval(-3_600),
                endedAt: nil
            ),
        ]
        let vm = makeViewModel(project: project)

        #expect(vm.totalDuration(referenceDate: referenceDate) == 5_400)
        #expect(vm.totalValueText(referenceDate: referenceDate) == TimeFormatting.euroAmount(150))
    }

    @Test("Today duration counts only overlapping portions")
    func todayDurationCountsOnlyOverlappingPortions() throws {
        let calendar = Calendar(identifier: .gregorian)
        let referenceDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 14, hour: 12)))
        let dayStart = calendar.startOfDay(for: referenceDate)
        let project = ClientProject(clientName: "Acme", name: "Website")
        project.sessions = [
            WorkSession(
                project: project,
                startedAt: dayStart.addingTimeInterval(-1_800),
                endedAt: dayStart.addingTimeInterval(1_800)
            ),
            WorkSession(
                project: project,
                startedAt: dayStart.addingTimeInterval(3_600),
                endedAt: dayStart.addingTimeInterval(7_200)
            ),
            WorkSession(
                project: project,
                startedAt: dayStart.addingTimeInterval(-7_200),
                endedAt: dayStart.addingTimeInterval(-3_600)
            ),
        ]
        let vm = makeViewModel(project: project)

        #expect(vm.todayDuration(referenceDate: referenceDate) == 5_400)
    }
}
