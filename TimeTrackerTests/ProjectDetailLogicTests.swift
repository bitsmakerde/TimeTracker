import Foundation
import Testing
import UniformTypeIdentifiers
@testable import TimeTracker

@Suite("Project Detail Logic")
@MainActor
struct ProjectDetailLogicTests {
    @Test("Project detail selected task falls back to first sorted task")
    func selectedTaskFallsBackToFirstSortedTask() throws {
        let project = ClientProject(clientName: "Acme", name: "Website")
        let betaTask = ProjectTask(title: "Beta", project: project)
        let alphaTask = ProjectTask(title: "Alpha", project: project)
        project.tasks = [betaTask, alphaTask]

        #expect(
            ProjectDetailLogic.selectedTaskForStart(
                project: project,
                selectedTaskID: nil
            )?.id == alphaTask.id
        )
        #expect(
            ProjectDetailLogic.selectedTaskForStart(
                project: project,
                selectedTaskID: betaTask.id
            )?.id == betaTask.id
        )
        #expect(
            ProjectDetailLogic.selectedTaskForStart(
                project: project,
                selectedTaskID: UUID()
            )?.id == alphaTask.id
        )
    }

    @Test("Project detail input validation reports invalid hourly rates and budgets")
    func inputValidationReportsInvalidHourlyRatesAndBudgets() {
        #expect(ProjectDetailLogic.hasInvalidHourlyRate("abc"))
        #expect(ProjectDetailLogic.hourlyRateHint(for: "abc") == "Bitte gib einen gueltigen nicht-negativen Betrag ein.")

        #expect(ProjectDetailLogic.hasInvalidHourlyRate("-1"))
        #expect(ProjectDetailLogic.hasInvalidHourlyRate("95,50") == false)
        #expect(ProjectDetailLogic.parsedHourlyRate(from: "95,50") == 95.5)

        #expect(ProjectDetailLogic.hasInvalidBudgetTarget("0"))
        #expect(ProjectDetailLogic.hasInvalidBudgetTarget("10") == false)
        #expect(ProjectDetailLogic.parsedBudgetTarget(from: "10") == 10)
    }

    @Test("Project detail budget editor converts between hours and amount")
    func budgetEditorConvertsBetweenHoursAndAmount() {
        let project = ClientProject(clientName: "Acme", name: "Website", hourlyRate: 100)

        #expect(
            ProjectDetailLogic.convertedBudgetEditorText(
                "2",
                project: project,
                from: .hours,
                to: .amount
            ) == "200"
        )
        #expect(
            ProjectDetailLogic.convertedBudgetEditorText(
                "200",
                project: project,
                from: .amount,
                to: .hours
            ) == "2"
        )
    }

    @Test("Project detail export state tracks prepared selection")
    func exportStateTracksPreparedSelection() {
        let project = ClientProject(clientName: "Acme", name: "Website", hourlyRate: 100)
        let selection = ProjectDetailLogic.currentExportSelection(
            format: .pdf,
            selectedMode: .hoursAndCosts,
            project: project
        )
        let preparedURL = URL.temporaryDirectory.appending(path: "export.pdf")

        #expect(
            ProjectDetailLogic.hasPreparedExport(
                preparedURL: preparedURL,
                preparedSelection: selection,
                currentSelection: selection
            )
        )

        let changedSelection = ProjectDetailLogic.currentExportSelection(
            format: .csv,
            selectedMode: .hoursAndCosts,
            project: project
        )
        #expect(changedSelection != selection)
        #expect(
            ProjectDetailLogic.hasPreparedExport(
                preparedURL: preparedURL,
                preparedSelection: selection,
                currentSelection: changedSelection
            ) == false
        )

        #expect(
            ProjectDetailLogic.hasPreparedExport(
                preparedURL: nil,
                preparedSelection: selection,
                currentSelection: selection
            ) == false
        )
    }

    @Test("Project budget snapshot status distinguishes remaining exact and over budget")
    func projectBudgetSnapshotStatusText() {
        let remaining = ProjectBudgetSnapshot(unit: .hours, target: 10, consumed: 7)
        let exact = ProjectBudgetSnapshot(unit: .hours, target: 10, consumed: 10)
        let over = ProjectBudgetSnapshot(unit: .hours, target: 10, consumed: 12)
        let formatter: (Double, ProjectBudgetUnit) -> String = { value, unit in
            "\(Int(value))-\(unit.rawValue)"
        }

        #expect(remaining.remaining == 3)
        #expect(remaining.progress == 0.7)
        #expect(remaining.isOverBudget == false)
        #expect(remaining.statusText(unitFormatter: formatter) == "Restbudget: 3-hours")

        #expect(exact.statusText(unitFormatter: formatter) == "Budget exakt erreicht")

        #expect(over.remaining == -2)
        #expect(over.progress == 1.2)
        #expect(over.isOverBudget)
        #expect(over.statusText(unitFormatter: formatter) == "Ueberzogen um 2-hours")
    }

    @Test("Project detail synchronizes task and alert state")
    func taskAndAlertStateSynchronization() {
        let project = ClientProject(clientName: "Acme", name: "Website")
        let betaTask = ProjectTask(
            title: "Beta",
            project: project,
            createdAt: Date(timeIntervalSince1970: 2)
        )
        let alphaTask = ProjectTask(
            title: "Alpha",
            project: project,
            createdAt: Date(timeIntervalSince1970: 1)
        )
        project.tasks = [betaTask, alphaTask]

        #expect(
            ProjectDetailLogic.synchronizedSelectedTaskID(
                project: project,
                selectedTaskID: UUID()
            ) == alphaTask.id
        )

        project.tasks = []
        #expect(
            ProjectDetailLogic.synchronizedSelectedTaskID(
                project: project,
                selectedTaskID: alphaTask.id
            ) == nil
        )

        #expect(
            ProjectDetailLogic.alertMessageAfterPresentationChange(
                currentMessage: "Fehler",
                isPresented: true
            ) == "Fehler"
        )
        #expect(
            ProjectDetailLogic.alertMessageAfterPresentationChange(
                currentMessage: "Fehler",
                isPresented: false
            ) == nil
        )

        let session = WorkSession(project: project)
        #expect(
            ProjectDetailLogic.pendingSessionAfterDeletionPresentationChange(
                currentSession: session,
                isPresented: true
            )?.id == session.id
        )
        #expect(
            ProjectDetailLogic.pendingSessionAfterDeletionPresentationChange(
                currentSession: session,
                isPresented: false
            ) == nil
        )
    }

    @Test("Project detail editor helpers sync hourly rate and budget state")
    func editorHelpersSyncHourlyRateAndBudgetState() {
        let project = ClientProject(
            clientName: "Acme",
            name: "Website",
            hourlyRate: 90
        )
        project.setBudget(unit: .amount, target: 450)

        #expect(TimeFormatting.parseDecimalInput(ProjectDetailLogic.hourlyRateText(for: project)) == 90)

        #expect(ProjectDetailLogic.budgetUnit(for: project) == .amount)
        #expect(TimeFormatting.parseDecimalInput(ProjectDetailLogic.budgetTargetText(for: project)) == 450)

        #expect(
            ProjectDetailLogic.toggledHourlyRateEditing(
                currentlyEditing: false,
                hasHourlyRate: project.hasHourlyRate
            )
        )
        #expect(
            ProjectDetailLogic.toggledHourlyRateEditing(
                currentlyEditing: false,
                hasHourlyRate: false
            )
        )
    }
}
