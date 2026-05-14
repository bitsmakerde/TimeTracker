import Foundation
import Testing
import UniformTypeIdentifiers
@testable import TimeTracker

@Suite("Project Detail Logic")
@MainActor
struct ProjectDetailLogicTests {
    @Test("Project detail totals include ended and active sessions")
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
        let view = makeView(project: project)

        #expect(view.totalDuration(referenceDate: referenceDate) == 5_400)
        #expect(view.totalValueText(referenceDate: referenceDate) == TimeFormatting.euroAmount(150))
    }

    @Test("Project detail today duration counts only overlapping portions")
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
        let view = makeView(project: project)

        #expect(view.todayDuration(referenceDate: referenceDate) == 5_400)
    }

    @Test("Project detail action metadata follows project and tracking state")
    func actionMetadataFollowsProjectAndTrackingState() {
        let project = ClientProject(clientName: "Acme", name: "Website")
        let activeSession = WorkSession(project: project, startedAt: .now)
        let archivedProject = ClientProject(clientName: "Acme", name: "Archive", archivedAt: .now)

        let idleView = makeView(project: project)
        #expect(idleView.actionButtonTitle == "Zeiterfassung starten")
        #expect(idleView.actionButtonSystemImage == "play.fill")

        let activeView = makeView(project: project, activeSession: activeSession)
        #expect(activeView.actionButtonTitle == "Zeiterfassung stoppen")
        #expect(activeView.actionButtonSystemImage == "stop.fill")
        #expect(activeView.isActiveProject)
        #expect(activeView.isProjectRunningWithoutTask)

        let archivedView = makeView(project: archivedProject)
        #expect(archivedView.actionButtonTitle == "Projekt reaktivieren")
        #expect(archivedView.actionButtonSystemImage == "arrow.uturn.backward.circle.fill")
    }

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

    @Test("Project detail task duration and value aggregate by task")
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
        let view = makeView(project: project)

        #expect(view.taskSessionCount(for: designTask) == 2)
        #expect(view.taskDuration(for: designTask, referenceDate: referenceDate) == 5_400)
        #expect(view.taskDuration(for: buildTask, referenceDate: referenceDate) == 1_800)
        #expect(view.taskValueText(for: designTask, referenceDate: referenceDate) == TimeFormatting.euroAmount(180))
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

    @Test("Project detail budget summaries cover missing, hour, and amount budgets")
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
        let view = makeView(project: project)

        #expect(view.budgetSummaryValue(referenceDate: referenceDate) == "Offen")
        #expect(view.budgetSummarySubtitle(referenceDate: referenceDate) == "Wert: Offen")

        project.setBudget(unit: .hours, target: 4)
        #expect(view.budgetHoursSummary(referenceDate: referenceDate) == "2h / 4h")
        #expect(view.budgetAmountSummary(referenceDate: referenceDate) == "200,00 € / 400,00 €")
        #expect(view.secondaryBudgetSummary(referenceDate: referenceDate, primaryUnit: .hours) == "Wert: 200,00 € / 400,00 €")

        project.setBudget(unit: .amount, target: 250)
        let snapshot = view.budgetSnapshot(referenceDate: referenceDate)
        #expect(snapshot?.unit == .amount)
        #expect(snapshot?.target == 250)
        #expect(snapshot?.consumed == 200)
        #expect(snapshot?.remaining == 50)
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

    @Test("Project detail export configuration follows hourly rate")
    func exportConfigurationFollowsHourlyRate() {
        let project = ClientProject(clientName: "Acme", name: "Website")
        let view = makeView(project: project)

        #expect(
            ProjectDetailLogic.normalizedExportContentMode(
                selectedMode: .hoursAndCosts,
                hasHourlyRate: false
            ) == .hoursOnly
        )
        #expect(ProjectDetailLogic.availableExportModes(hasHourlyRate: false) == [.hoursOnly])

        let staleSelection = ProjectExportSelection(format: .pdf, mode: .hoursAndCosts)
        let currentSelection = ProjectDetailLogic.currentExportSelection(
            format: .pdf,
            selectedMode: .hoursAndCosts,
            project: project
        )
        #expect(
            ProjectDetailLogic.hasPreparedExport(
                preparedURL: URL.temporaryDirectory.appending(path: "stale.pdf"),
                preparedSelection: staleSelection,
                currentSelection: currentSelection
            ) == false
        )

        let preparedURL = view.makePreparedExportURL(for: .csv)
        #expect(preparedURL.pathExtension == "csv")
        #expect(preparedURL.lastPathComponent.localizedStandardContains("Website-Export"))

        project.hourlyRate = 120
        #expect(ProjectDetailLogic.availableExportModes(hasHourlyRate: project.hasHourlyRate) == ProjectExportContentMode.allCases)

#if os(macOS)
        #expect(view.utType(for: .csv) == .commaSeparatedText)
        #expect(view.utType(for: .pdf) == .pdf)
#endif
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

    private func makeView(
        project: ClientProject,
        activeSession: WorkSession? = nil
    ) -> ProjectDetailView {
        ProjectDetailView(
            project: project,
            activeSession: activeSession,
            onStart: {},
            onStartTask: { _ in },
            onStop: {},
            onAddManualEntry: {},
            onEditSession: { _ in },
            onDeleteSession: { _ in },
            onArchiveProject: {},
            onRestoreProject: {},
            onDeleteProject: {}
        )
    }
}
