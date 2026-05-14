import Foundation
import Testing
@testable import TimeTracker

@Suite("Project Detail Budget Sheet")
@MainActor
struct ProjectDetailBudgetSheetTests {
    private func makeViewModel(
        project: ClientProject,
        activeSession: WorkSession? = nil
    ) -> ProjectDetailViewModel {
        ProjectDetailViewModel(project: project, activeSession: activeSession)
    }

    @Test("Budget summaries cover missing, hour, and amount budgets")
    func budgetSummariesCoverMissingHourAndAmountBudgets() {
        let referenceDate = Date(timeIntervalSince1970: 30_000)
        let project = ClientProject(clientName: "Acme", name: "Website", hourlyRate: 100)
        project.sessions = [
            WorkSession(
                project: project,
                startedAt: referenceDate.addingTimeInterval(-7_200),
                endedAt: referenceDate
            ),
        ]
        let vm = makeViewModel(project: project)

        #expect(vm.budgetSummaryValue(referenceDate: referenceDate) == "Offen")
        #expect(vm.budgetSummarySubtitle(referenceDate: referenceDate) == "Wert: Offen")

        project.setBudget(unit: .hours, target: 4)
        let amountSummary = "\(TimeFormatting.euroAmount(200)) / \(TimeFormatting.euroAmount(400))"
        #expect(vm.budgetHoursSummary(referenceDate: referenceDate) == "2h / 4h")
        #expect(vm.budgetAmountSummary(referenceDate: referenceDate) == amountSummary)
        #expect(vm.secondaryBudgetSummary(referenceDate: referenceDate, primaryUnit: .hours) == "Wert: \(amountSummary)")

        project.setBudget(unit: .amount, target: 250)
        let snapshot = vm.budgetSnapshot(referenceDate: referenceDate)
        #expect(snapshot?.unit == .amount)
        #expect(snapshot?.target == 250)
        #expect(snapshot?.consumed == 200)
        #expect(snapshot?.remaining == 50)
    }
}
