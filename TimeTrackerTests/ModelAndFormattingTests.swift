import Foundation
import CoreGraphics
import SwiftData
import SwiftUI
import Testing
@testable import TimeTracker

@Suite("Model and Formatting")
struct ModelAndFormattingTests {
    @Test("TimeFormatting returns expected digital and compact durations")
    func durationFormatting() {
        #expect(TimeFormatting.digitalDuration(3661) == "01:01:01")
        #expect(TimeFormatting.compactDuration(59 * 60) == "59m")
        #expect(TimeFormatting.compactDuration(3600) == "1h")
        #expect(TimeFormatting.compactDuration(3720) == "1h 2m")
        #expect(TimeFormatting.menuBarDuration(3720) == "1:02")
    }

    @Test("TimeFormatting parses decimal input for German and normalized formats")
    func decimalParsing() {
        #expect(TimeFormatting.parseDecimalInput("95,5") == 95.5)
        #expect(TimeFormatting.parseDecimalInput("95.5") == 95.5)
        #expect(TimeFormatting.parseDecimalInput("1.000") == 1000)
        #expect(TimeFormatting.parseDecimalInput("1,000") == 1000)
        #expect(TimeFormatting.parseDecimalInput("") == nil)
        #expect(TimeFormatting.parseDecimalInput("abc") == nil)
    }

    @Test("TimeFormatting emits euro strings and decimal input")
    func monetaryFormatting() {
        let amountText = TimeFormatting.euroAmount(123.45)
        #expect(amountText.contains("€"))

        let decimalText = TimeFormatting.decimalInput(123.45)
        #expect(TimeFormatting.parseDecimalInput(decimalText) == 123.45)
        #expect(TimeFormatting.decimalInput(nil) == "")
    }

    @Test("TimeFormatting short date and time produce readable output")
    func shortDateAndTimeFormatting() {
        let date = Date(timeIntervalSince1970: 1_704_067_200) // 1 Jan 2024

        #expect(TimeFormatting.shortDate(date).isEmpty == false)
        #expect(TimeFormatting.shortTime(date).isEmpty == false)
    }

    @Test("ClientProject computed properties and sorting are stable")
    func projectComputedProperties() {
        let project = ClientProject(
            clientName: "  Kunde X ",
            name: "  Projekt A ",
            notes: "",
            hourlyRate: 120
        )

        let sessionOld = WorkSession(
            project: project,
            startedAt: Date(timeIntervalSince1970: 10),
            endedAt: Date(timeIntervalSince1970: 20)
        )
        let sessionNew = WorkSession(
            project: project,
            startedAt: Date(timeIntervalSince1970: 30),
            endedAt: Date(timeIntervalSince1970: 40)
        )
        project.sessions = [sessionOld, sessionNew]

        let taskAOld = ProjectTask(
            title: "alpha",
            project: project,
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let taskANew = ProjectTask(
            title: "alpha",
            project: project,
            createdAt: Date(timeIntervalSince1970: 2)
        )
        let taskB = ProjectTask(
            title: "beta",
            project: project,
            createdAt: Date(timeIntervalSince1970: 0)
        )
        project.tasks = [taskB, taskANew, taskAOld]

        #expect(project.displayClientName == "Kunde X")
        #expect(project.displayName == "Projekt A")
        #expect(project.sortedSessions.map(\.id) == [sessionNew.id, sessionOld.id])
        #expect(project.sortedTasks.map(\.id) == [taskAOld.id, taskANew.id, taskB.id])
        #expect(project.hasHourlyRate)
        #expect(project.effectiveHourlyRate == 120)
        #expect(project.billedAmount(for: 1800) == 60)
    }

    @Test("Fallback labels work for empty values")
    func fallbackLabels() {
        let project = ClientProject(clientName: "   ", name: "   ")
        let task = ProjectTask(title: "   ", project: project)
        let session = WorkSession(project: project, task: nil)

        #expect(project.displayClientName == "Ohne Kunde")
        #expect(project.displayName == "Unbenanntes Projekt")
        #expect(task.displayTitle == "Unbenannte Aufgabe")
        #expect(session.displayTaskTitle == "Ohne Aufgabe")
    }

    @Test("ClientProject archive and billing helpers cover edge cases")
    func projectArchiveAndBillingEdgeCases() {
        let projectWithoutRate = ClientProject(clientName: "A", name: "B")
        #expect(projectWithoutRate.isArchived == false)
        #expect(projectWithoutRate.billedAmount(for: 3600) == nil)

        let archivedProject = ClientProject(
            clientName: "A",
            name: "B",
            hourlyRate: -80,
            archivedAt: Date(timeIntervalSince1970: 42)
        )
        #expect(archivedProject.isArchived)
        #expect(archivedProject.effectiveHourlyRate == 0)
        #expect(archivedProject.billedAmount(for: -120) == 0)
    }

    @Test("ClientProject budget helpers support hours and euro targets")
    func projectBudgetHelpers() {
        let project = ClientProject(
            clientName: "A",
            name: "B",
            hourlyRate: 150
        )

        #expect(project.hasBudget == false)
        #expect(project.budgetUnit == nil)
        #expect(project.effectiveBudgetTarget == nil)

        project.setBudget(unit: .hours, target: 12)
        #expect(project.hasBudget)
        #expect(project.budgetUnit == .hours)
        #expect(project.budgetUnitRaw == ProjectBudgetUnit.hours.rawValue)
        #expect(project.effectiveBudgetTarget == 12)
        #expect(project.budgetConsumedValue(for: 3 * 3600) == 3)
        #expect(project.budgetRemainingValue(for: 3 * 3600) == 9)
        #expect(project.budgetProgressFraction(for: 3 * 3600) == 0.25)
        #expect(project.budgetTargetValue(in: .hours) == 12)
        #expect(project.budgetTargetValue(in: .amount) == 1800)
        #expect(project.convertedBudgetValue(20, from: .hours, to: .amount) == 3000)

        project.setBudget(unit: .amount, target: 900)
        #expect(project.budgetUnit == .amount)
        #expect(project.budgetConsumedValue(for: 2 * 3600) == 300)
        #expect(project.budgetRemainingValue(for: 2 * 3600) == 600)
        #expect(project.budgetProgressFraction(for: 8 * 3600) == (1200.0 / 900.0))
        #expect(project.budgetTargetValue(in: .amount) == 900)
        #expect(project.budgetTargetValue(in: .hours) == 6)
        #expect(project.convertedBudgetValue(3000, from: .amount, to: .hours) == 20)

        project.hourlyRate = nil
        #expect(project.budgetConsumedValue(for: 3600) == nil)
        #expect(project.budgetRemainingValue(for: 3600) == nil)
        #expect(project.budgetProgressFraction(for: 3600) == nil)
        #expect(project.budgetTargetValue(in: .hours) == nil)
        #expect(project.convertedBudgetValue(20, from: .hours, to: .amount) == nil)

        project.setBudget(unit: .hours, target: 0)
        #expect(project.hasBudget == false)
        #expect(project.budgetUnit == nil)
        #expect(project.budgetUnitRaw == nil)
        #expect(project.effectiveBudgetTarget == nil)
    }

    @Test("ClientProject allows custom accent color and reset to automatic")
    func projectAccentColorCustomization() {
        let project = ClientProject(clientName: "A", name: "B")

        #expect(project.hasCustomAccentColor == false)

        project.setCustomAccentColor(.red)
        #expect(project.hasCustomAccentColor)
        #expect(project.accentRed != nil)
        #expect(project.accentGreen != nil)
        #expect(project.accentBlue != nil)

        project.clearCustomAccentColor()
        #expect(project.hasCustomAccentColor == false)
        #expect(project.accentRed == nil)
        #expect(project.accentGreen == nil)
        #expect(project.accentBlue == nil)
    }

    @Test("Project color helpers expose variant ids and tinted accents")
    func projectColorHelpers() {
        let project = ClientProject(clientName: "Acme", name: "Website")
        let tint = project.accentTint(0.2)

        #expect(ProjectColorVariant.tinted.id == "tinted")
        #expect(ProjectColorVariant.chromed.id == "chromed")

        _ = tint
    }

    @Test("WorkSession duration helpers reflect active and ended states")
    func workSessionDurationHelpers() {
        let project = ClientProject(clientName: "A", name: "B")
        let start = Date(timeIntervalSince1970: 100)
        let activeSession = WorkSession(project: project, startedAt: start)

        #expect(activeSession.isActive)
        #expect(activeSession.duration(referenceDate: Date(timeIntervalSince1970: 160)) == 60)

        activeSession.endedAt = Date(timeIntervalSince1970: 130)
        #expect(activeSession.isActive == false)
        #expect(activeSession.duration(referenceDate: Date(timeIntervalSince1970: 200)) == 30)
        #expect(activeSession.recordedDuration == 30)

        activeSession.endedAt = Date(timeIntervalSince1970: 90)
        #expect(activeSession.duration(referenceDate: Date(timeIntervalSince1970: 200)) == 0)
    }

    @Test("TrackingManagerError provides localized descriptions for all cases")
    func trackingManagerErrorDescriptions() {
        let allErrors: [TrackingManagerError] = [
            .invalidDateRange,
            .futureDateNotAllowed,
            .activeSessionEditingNotAllowed,
            .archivedProjectNotEditable,
            .invalidTaskAssignment,
        ]

        for error in allErrors {
            #expect(error.errorDescription?.isEmpty == false)
        }
    }

    @Test("Project export document groups tasks, durations, and optional costs")
    func projectExportDocumentGeneration() {
        let project = ClientProject(
            clientName: "Export Kunde",
            name: "Export Projekt",
            hourlyRate: 100
        )
        let task = ProjectTask(
            title: "Entwicklung",
            project: project,
            createdAt: Date(timeIntervalSince1970: 1)
        )
        project.tasks = [task]

        let firstSession = WorkSession(
            project: project,
            task: task,
            startedAt: Date(timeIntervalSince1970: 10),
            endedAt: Date(timeIntervalSince1970: 3_610)
        )
        let secondSession = WorkSession(
            project: project,
            task: nil,
            startedAt: Date(timeIntervalSince1970: 5_000),
            endedAt: Date(timeIntervalSince1970: 6_800)
        )
        project.sessions = [secondSession, firstSession]

        let hoursOnlyDocument = ProjectExportService.makeDocument(
            for: project,
            mode: .hoursOnly,
            referenceDate: Date(timeIntervalSince1970: 7_000)
        )

        #expect(hoursOnlyDocument.mode == .hoursOnly)
        #expect(hoursOnlyDocument.totalDuration == 5_400)
        #expect(hoursOnlyDocument.totalCost == nil)
        #expect(hoursOnlyDocument.taskSummaries.count == 2)
        #expect(hoursOnlyDocument.sessionRows.count == 2)

        let costDocument = ProjectExportService.makeDocument(
            for: project,
            mode: .hoursAndCosts,
            referenceDate: Date(timeIntervalSince1970: 7_000)
        )

        #expect(costDocument.mode == .hoursAndCosts)
        #expect(costDocument.totalCost == 150)

        let csvWithCosts = ProjectExportService.csvString(from: costDocument)
        #expect(csvWithCosts.localizedStandardContains("Kosten (EUR)"))
        #expect(csvWithCosts.localizedStandardContains("Entwicklung"))
        #expect(csvWithCosts.localizedStandardContains("Ohne Aufgabe"))

        project.hourlyRate = nil

        let fallbackDocument = ProjectExportService.makeDocument(
            for: project,
            mode: .hoursAndCosts,
            referenceDate: Date(timeIntervalSince1970: 7_000)
        )

        #expect(fallbackDocument.mode == .hoursOnly)

        let csvWithoutCosts = ProjectExportService.csvString(from: fallbackDocument)
        #expect(csvWithoutCosts.localizedStandardContains("Kosten (EUR)") == false)
    }

    @Test("Project export creates a PDF payload")
    func projectExportPDFPayload() throws {
        let project = ClientProject(
            clientName: "Export Kunde",
            name: "Export Projekt",
            hourlyRate: 120
        )
        let task = ProjectTask(title: "QA", project: project)
        project.tasks = [task]
        project.sessions = [
            WorkSession(
                project: project,
                task: task,
                startedAt: Date(timeIntervalSince1970: 100),
                endedAt: Date(timeIntervalSince1970: 1_900)
            ),
        ]

        let document = ProjectExportService.makeDocument(
            for: project,
            mode: .hoursAndCosts,
            referenceDate: Date(timeIntervalSince1970: 2_000)
        )

        let pdfData = ProjectExportService.pdfData(from: document)
        #expect(pdfData.isEmpty == false)

        let headerData = try #require(
            String(data: pdfData.prefix(5), encoding: .ascii)
        )
        #expect(headerData == "%PDF-")
    }

    @Test("Project export PDF keeps text upright")
    func projectExportPDFUprightTextTransform() throws {
        let project = ClientProject(
            clientName: "Export Kunde",
            name: "Export Projekt",
            hourlyRate: 120
        )
        project.sessions = [
            WorkSession(
                project: project,
                startedAt: Date(timeIntervalSince1970: 100),
                endedAt: Date(timeIntervalSince1970: 1_900)
            ),
        ]

        let document = ProjectExportService.makeDocument(
            for: project,
            mode: .hoursAndCosts,
            referenceDate: Date(timeIntervalSince1970: 2_000)
        )

        let pdfData = ProjectExportService.pdfData(from: document)
        let contentStreamText = try #require(pdfContentStreamText(from: pdfData))
        let yScales = matrixYScaleValues(from: contentStreamText)

        #expect(yScales.contains(where: { $0 < 0 }) == false)
    }

    @Test("Project export file naming sanitizes invalid characters")
    func projectExportFileNameSanitizing() {
        #expect(ProjectExportFileNaming.sanitizedFileNameComponent("A/B:C") == "A-B-C")
        #expect(ProjectExportFileNaming.sanitizedFileNameComponent("   ") == "Projekt")
        #expect(ProjectExportFileNaming.sanitizedFileNameComponent("/:*?\"<>|") == "Projekt")
    }

    @Test("Project export file naming uses date stamp and extension")
    func projectExportDefaultFileName() {
        let date = Date(timeIntervalSince1970: 1_704_067_200) // 1 Jan 2024
        let csvName = ProjectExportFileNaming.defaultFileName(
            projectName: "Projekt A",
            format: .csv,
            date: date
        )
        let pdfName = ProjectExportFileNaming.defaultFileName(
            projectName: "Projekt A",
            format: .pdf,
            date: date
        )

        #expect(csvName == "Projekt A-Export-2024-01-01.csv")
        #expect(pdfName == "Projekt A-Export-2024-01-01.pdf")
    }

    @Test("Project export metadata and CSV payload escape special values")
    func projectExportMetadataAndCSVEscaping() throws {
        #expect(ProjectExportContentMode.hoursOnly.title == "Nur Stunden")
        #expect(ProjectExportContentMode.hoursAndCosts.title == "Stunden + Kosten")
        #expect(ProjectExportFormat.csv.title == "CSV")
        #expect(ProjectExportFormat.pdf.title == "PDF")
        #expect(ProjectExportFormat.csv.fileExtension == "csv")
        #expect(ProjectExportFormat.pdf.fileExtension == "pdf")

        let project = ClientProject(
            clientName: "ACME \"Nord\"",
            name: "Export; Projekt",
            hourlyRate: 90
        )
        let removedTask = ProjectTask(title: "Plan;\"A\"", project: project)
        project.sessions = [
            WorkSession(
                project: project,
                task: removedTask,
                startedAt: Date(timeIntervalSince1970: 100),
                endedAt: Date(timeIntervalSince1970: 3_700)
            ),
            WorkSession(
                project: project,
                startedAt: Date(timeIntervalSince1970: 5_000),
                endedAt: nil
            ),
        ]
        project.tasks = []

        let document = ProjectExportService.makeDocument(
            for: project,
            mode: .hoursAndCosts,
            referenceDate: Date(timeIntervalSince1970: 7_000)
        )
        let csvData = ProjectExportService.exportData(
            document: document,
            format: .csv
        )
        let csv = try #require(String(data: csvData, encoding: .utf8))

        #expect(document.taskSummaries.map(\.taskTitle).contains("Aufgabe entfernt"))
        #expect(csv.localizedStandardContains("\"Export; Projekt\""))
        #expect(csv.localizedStandardContains("\"ACME \"\"Nord\"\"\""))
        #expect(csv.localizedStandardContains("\"Plan;\"\"A\"\"\""))
        #expect(csv.localizedStandardContains("Aktiv"))
    }

    @Test("Project detail layout metrics adapt to compact and accessibility sizes")
    func projectDetailLayoutMetrics() {
        #expect(ProjectDetailLayoutMetrics.contentPadding(horizontalSizeClass: .compact) == 16)
        #expect(ProjectDetailLayoutMetrics.contentPadding(horizontalSizeClass: .regular) == 24)

        #expect(ProjectDetailLayoutMetrics.sectionPadding(horizontalSizeClass: .compact) == 16)
        #expect(ProjectDetailLayoutMetrics.sectionPadding(horizontalSizeClass: .regular) == 24)

        #expect(ProjectDetailLayoutMetrics.summaryGridMinimum(horizontalSizeClass: .compact) == 140)
        #expect(ProjectDetailLayoutMetrics.summaryGridMinimum(horizontalSizeClass: .regular) == 180)

        #expect(
            ProjectDetailLayoutMetrics.usesStackedRow(
                dynamicTypeSize: .large,
                horizontalSizeClass: .compact
            )
        )
        #expect(
            ProjectDetailLayoutMetrics.usesStackedRow(
                dynamicTypeSize: .accessibility1,
                horizontalSizeClass: .regular
            )
        )
        #expect(
            ProjectDetailLayoutMetrics.usesStackedRow(
                dynamicTypeSize: .large,
                horizontalSizeClass: .regular
            ) == false
        )

        #expect(
            ProjectDetailLayoutMetrics.sessionRowSpacing(
                dynamicTypeSize: .large,
                horizontalSizeClass: .compact
            ) == 10
        )
        #expect(
            ProjectDetailLayoutMetrics.sessionRowSpacing(
                dynamicTypeSize: .large,
                horizontalSizeClass: .regular
            ) == 12
        )
        #expect(
            ProjectDetailLayoutMetrics.sessionRowSpacing(
                dynamicTypeSize: .accessibility1,
                horizontalSizeClass: .regular
            ) == 10
        )

        #expect(
            ProjectDetailLayoutMetrics.sessionRowPadding(
                dynamicTypeSize: .large,
                horizontalSizeClass: .compact
            ) == 12
        )
        #expect(
            ProjectDetailLayoutMetrics.sessionRowPadding(
                dynamicTypeSize: .large,
                horizontalSizeClass: .regular
            ) == 18
        )
        #expect(
            ProjectDetailLayoutMetrics.sessionRowPadding(
                dynamicTypeSize: .accessibility1,
                horizontalSizeClass: .regular
            ) == 12
        )
    }

    @MainActor
    @Test("Mac root view model chooses explicit, active, then first active project")
    func macRootViewModelSelectionPriority() {
        let activeProject = ClientProject(clientName: "A", name: "Active")
        let selectedProject = ClientProject(clientName: "B", name: "Selected")
        let archivedProject = ClientProject(clientName: "C", name: "Archived")
        archivedProject.archivedAt = Date(timeIntervalSince1970: 1_000)
        let activeSession = WorkSession(project: activeProject, startedAt: Date(timeIntervalSince1970: 2_000))
        let viewModel = MacRedesignedRootViewModel()

        #expect(viewModel.activeProjects(from: [archivedProject, activeProject, selectedProject]).map(\.id) == [activeProject.id, selectedProject.id])
        #expect(viewModel.selectedProject(from: [archivedProject, activeProject, selectedProject], activeSession: activeSession)?.id == activeProject.id)

        viewModel.selectedProjectID = selectedProject.id

        #expect(viewModel.selectedProject(from: [archivedProject, activeProject, selectedProject], activeSession: activeSession)?.id == selectedProject.id)
    }

    @MainActor
    @Test("Mac root view model exposes sheet and alert bindings")
    func macRootViewModelBindings() {
        let viewModel = MacRedesignedRootViewModel()

        viewModel.errorMessage = "Fehler"
        #expect(viewModel.errorIsPresented)

        viewModel.errorIsPresented = false

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.errorIsPresented == false)
    }

    @Test("Project export selection normalizes mode without hourly rate")
    func projectExportSelectionNormalization() {
        let normalizedWithoutRate = ProjectExportSelection.current(
            format: .pdf,
            selectedMode: .hoursAndCosts,
            hasHourlyRate: false
        )
        #expect(normalizedWithoutRate == ProjectExportSelection(format: .pdf, mode: .hoursOnly))

        let withRate = ProjectExportSelection.current(
            format: .csv,
            selectedMode: .hoursAndCosts,
            hasHourlyRate: true
        )
        #expect(withRate == ProjectExportSelection(format: .csv, mode: .hoursAndCosts))

        #expect(normalizedWithoutRate != withRate)
    }

    @Test("Project creation draft validates input and applies custom color")
    func projectCreationDraftValidationAndCustomColor() throws {
        var invalidDraft = ProjectCreationDraft(initialClientName: "Bestandskunde")
        invalidDraft.projectName = "   "
        invalidDraft.hourlyRateText = "-1"

        #expect(invalidDraft.hasInvalidHourlyRate)
        #expect(invalidDraft.canSave == false)
        #expect(invalidDraft.makeProject() == nil)

        var draft = ProjectCreationDraft(initialClientName: "  Kunde A  ")
        draft.projectName = "  Launch  "
        draft.notes = "Konzeption"
        draft.hourlyRateText = "120,5"
        draft.usesCustomProjectColor = true
        draft.projectColor = .orange

        let project = try #require(draft.makeProject())
        #expect(project.displayClientName == "Kunde A")
        #expect(project.displayName == "Launch")
        #expect(project.notes == "Konzeption")
        #expect(project.hourlyRate == 120.5)
        #expect(project.hasCustomAccentColor)
    }

    @MainActor
    @Test("Preview helpers provide a usable store and iOS-flavored dependencies")
    func previewHelpersProvideStoreAndDependencies() throws {
        let container = ModelContainer.preview
        let context = container.mainContext
        let project = ClientProject(clientName: "Preview", name: "Store")
        let session = WorkSession(
            project: project,
            startedAt: Date(timeIntervalSince1970: 100)
        )

        context.insert(project)
        context.insert(session)
        try context.save()

        let activeSampleSessions = WorkSession.sampleActiveData(for: ClientProject.sampleData)
        let trackingStatus = TrackingStatusStore.preview(modelContainer: container)
        let dependencies = AppDependencies.preview
        trackingStatus.refresh()

        #expect(activeSampleSessions.count == 1)
        #expect(activeSampleSessions.contains { $0.isActive } == true)
        #expect(dependencies.configuration.platform == .iOS)
        #expect(trackingStatus.isTracking)
        #expect(trackingStatus.activeSession?.projectName == "Store")
    }

    @Test("Shared metadata exposes stable labels and identifiers")
    func sharedMetadataLabelsAndIdentifiers() {
        #expect(ProjectBudgetUnit.allCases.map(\.id) == ["hours", "amount"])
        #expect(ProjectColorVariant.allCases.map(\.label) == ["Wash", "Bar"])

        let project = ClientProject(clientName: "  acme  ", name: "Website")
        let fallbackProject = ClientProject(clientName: "   ", name: "Fallback")

        #expect(project.clientInitial == "A")
        #expect(fallbackProject.clientInitial == "O")
    }

    @Test("Target configurations expose expected feature flags")
    func targetConfigurationsExposeExpectedFeatureFlags() {
        #expect(TimeTrackerTargetConfiguration.macOS.platform == .macOS)
        #expect(TimeTrackerTargetConfiguration.macOS.featureFlags.usesNativeCompactTabBar == false)
        #expect(TimeTrackerTargetConfiguration.macOS.featureFlags.showsMenuBarModule)
        #expect(TimeTrackerTargetConfiguration.macOS.featureFlags.enablesPreparedExports)

        #expect(TimeTrackerTargetConfiguration.iOS.platform == .iOS)
        #expect(TimeTrackerTargetConfiguration.iOS.featureFlags.usesNativeCompactTabBar)
        #expect(TimeTrackerTargetConfiguration.iOS.featureFlags.showsMenuBarModule == false)
        #expect(TimeTrackerTargetConfiguration.iOS.featureFlags.enablesPreparedExports)
    }

    @Test("Analytics aggregator applies week, month, year, and custom ranges")
    func analyticsAggregatorAppliesNamedRanges() {
        let calendar = Self.analyticsCalendar
        let referenceDate = analyticsDate(
            year: 2026,
            month: 5,
            day: 14,
            hour: 12,
            calendar: calendar
        )
        let projects = analyticsProjects(
            referenceDate: referenceDate,
            calendar: calendar
        )

        let weekSnapshot = AnalyticsAggregator.snapshot(
            projects: projects,
            selection: .init(period: .week),
            referenceDate: referenceDate,
            calendar: calendar
        )
        #expect(weekSnapshot.rangeTitle == "Woche")
        #expect(weekSnapshot.totalDuration == 18_000)
        #expect(weekSnapshot.totalValue == 400)
        #expect(weekSnapshot.todayDuration == 9_000)
        #expect(weekSnapshot.weekDuration == 18_000)
        #expect(weekSnapshot.averageDailyDuration == 4_500)
        #expect(weekSnapshot.projectCount == 2)
        #expect(weekSnapshot.entryCount == 4)
        #expect(weekSnapshot.projectBars.map(\.projectId) == [projects[0].id, projects[1].id])
        #expect(abs(weekSnapshot.projectBars[0].percentage - 0.8) < 0.0001)
        #expect(weekSnapshot.weekBars.count == 7)
        #expect(weekSnapshot.weekBars.reduce(0) { $0 + $1.totalMinutes } == 300)
        #expect(weekSnapshot.weekBars.first { $0.isToday }?.totalMinutes == 150)
        #expect(weekSnapshot.day.first { $0.hour == 0 }?.parts.map(\.minutes).reduce(0, +) == 90)
        #expect(weekSnapshot.day.first { $0.hour == 10 }?.parts.map(\.minutes).reduce(0, +) == 60)
        #expect(weekSnapshot.day.first { $0.hour == 11 }?.parts.map(\.minutes).reduce(0, +) == 60)
        #expect(weekSnapshot.day.first { $0.hour == 14 }?.parts.map(\.minutes).reduce(0, +) == 60)

        let monthSnapshot = AnalyticsAggregator.snapshot(
            projects: projects,
            selection: .init(period: .month),
            referenceDate: referenceDate,
            calendar: calendar
        )
        #expect(monthSnapshot.rangeTitle == "Monat")
        #expect(monthSnapshot.totalDuration == 39_600)
        #expect(monthSnapshot.totalValue == 1_000)
        #expect(monthSnapshot.todayDuration == 9_000)
        #expect(monthSnapshot.weekDuration == 18_000)
        #expect(monthSnapshot.averageDailyDuration == 39_600.0 / 14.0)
        #expect(monthSnapshot.projectCount == 2)
        #expect(monthSnapshot.entryCount == 6)
        #expect(monthSnapshot.weekBars.count == 31)
        #expect(monthSnapshot.weekBars.reduce(0) { $0 + $1.totalMinutes } == 660)
        #expect(monthSnapshot.day.first { $0.hour == 9 }?.parts.map(\.minutes).reduce(0, +) == 120)

        let yearSnapshot = AnalyticsAggregator.snapshot(
            projects: projects,
            selection: .init(period: .year),
            referenceDate: referenceDate,
            calendar: calendar
        )
        #expect(yearSnapshot.rangeTitle == "Jahr")
        #expect(yearSnapshot.totalDuration == 50_400)
        #expect(yearSnapshot.totalValue == 1_300)
        #expect(yearSnapshot.todayDuration == 9_000)
        #expect(yearSnapshot.weekDuration == 18_000)
        #expect(yearSnapshot.averageDailyDuration == 50_400.0 / 134.0)
        #expect(yearSnapshot.projectCount == 2)
        #expect(yearSnapshot.entryCount == 7)
        #expect(yearSnapshot.weekBars.count == 12)
        #expect(yearSnapshot.weekBars.reduce(0) { $0 + $1.totalMinutes } == 840)

        let customSnapshot = AnalyticsAggregator.snapshot(
            projects: projects,
            selection: .init(
                period: .custom,
                customStart: analyticsDate(year: 2026, month: 5, day: 10, calendar: calendar),
                customEnd: analyticsDate(year: 2026, month: 5, day: 14, calendar: calendar)
            ),
            referenceDate: referenceDate,
            calendar: calendar
        )
        #expect(customSnapshot.rangeTitle == "Individuell")
        #expect(customSnapshot.totalDuration == 32_400)
        #expect(customSnapshot.totalValue == 800)
        #expect(customSnapshot.todayDuration == 9_000)
        #expect(customSnapshot.weekDuration == 18_000)
        #expect(customSnapshot.averageDailyDuration == 6_480)
        #expect(customSnapshot.projectCount == 2)
        #expect(customSnapshot.entryCount == 5)
        #expect(customSnapshot.weekBars.count == 5)
        #expect(customSnapshot.weekBars.reduce(0) { $0 + $1.totalMinutes } == 540)
    }

    @Test("Analytics aggregator returns stable empty chart buckets")
    func analyticsAggregatorEmptySnapshotBuckets() {
        let calendar = Self.analyticsCalendar
        let referenceDate = analyticsDate(
            year: 2026,
            month: 5,
            day: 14,
            hour: 12,
            calendar: calendar
        )

        let snapshot = AnalyticsAggregator.snapshot(
            projects: [],
            selection: .init(period: .week),
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(snapshot.totalDuration == 0)
        #expect(snapshot.totalValue == 0)
        #expect(snapshot.todayDuration == 0)
        #expect(snapshot.weekDuration == 0)
        #expect(snapshot.averageDailyDuration == 0)
        #expect(snapshot.projectCount == 0)
        #expect(snapshot.entryCount == 0)
        #expect(snapshot.projectBars.isEmpty)
        #expect(snapshot.weekBars.count == 7)
        #expect(snapshot.day.count == 24)
    }

    @Test("Analytics top projects visualization switches between bars, pie, and empty states")
    func analyticsTopProjectsVisualizationStates() {
        let sampleItems = ["Website", "App"]

        #expect(
            AnalyticsTopProjectsDisplayMode.bar.presentation(for: sampleItems)
                == .bars(sampleItems)
        )
        #expect(
            AnalyticsTopProjectsDisplayMode.pie.presentation(for: sampleItems)
                == .pie(sampleItems)
        )
        #expect(
            AnalyticsTopProjectsDisplayMode.pie.presentation(for: [String]())
                == .empty
        )
    }

    @Test("Analytics export supports CSV and PDF output")
    func analyticsExportSupportsCSVAndPDF() throws {
        let calendar = Self.analyticsCalendar
        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 5, day: 15, hour: 12))
        )
        let project = ClientProject(
            clientName: "Acme",
            name: "Website",
            hourlyRate: 100
        )
        project.sessions = [
            WorkSession(
                project: project,
                startedAt: referenceDate.addingTimeInterval(-7_200),
                endedAt: referenceDate.addingTimeInterval(-3_600)
            ),
        ]

        let snapshot = AnalyticsAggregator.snapshot(
            projects: [project],
            selection: .init(
                period: .custom,
                customStart: analyticsDate(year: 2026, month: 5, day: 15, calendar: calendar),
                customEnd: analyticsDate(year: 2026, month: 5, day: 15, calendar: calendar)
            ),
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(AnalyticsExportService.supportedFormats == ProjectExportFormat.allCases)
        #expect(
            AnalyticsExportService.defaultFileName(
                for: .csv,
                exportedAt: referenceDate
            ).hasSuffix(".csv")
        )

        let csvData = AnalyticsExportService.exportData(
            snapshot: snapshot,
            format: .csv,
            exportedAt: referenceDate
        )
        let csvText = String(data: csvData, encoding: .utf8) ?? ""
        #expect(csvText.localizedStandardContains("Top-Projekte"))
        #expect(csvText.localizedStandardContains("CSV"))
        #expect(csvText.localizedStandardContains("Zeitraum"))
        #expect(csvText.localizedStandardContains("Individuell"))
        #expect(csvText.localizedStandardContains("Verlauf"))

        let pdfData = AnalyticsExportService.exportData(
            snapshot: snapshot,
            format: .pdf,
            exportedAt: referenceDate
        )
        #expect(pdfData.isEmpty == false)
    }

    private func pdfContentStreamText(from pdfData: Data) -> String? {
        guard let provider = CGDataProvider(data: pdfData as CFData),
              let pdfDocument = CGPDFDocument(provider),
              let firstPage = pdfDocument.page(at: 1) else {
            return nil
        }

        guard let pageDictionary = firstPage.dictionary else {
            return nil
        }
        let streamData = contentStreamData(from: pageDictionary)

        guard !streamData.isEmpty else {
            return nil
        }

        return String(data: streamData, encoding: .ascii)
    }

    private func contentStreamData(from pageDictionary: CGPDFDictionaryRef) -> Data {
        var streamData = Data()
        var directStream: CGPDFStreamRef?

        let hasDirectStream = "Contents".withCString { key in
            CGPDFDictionaryGetStream(pageDictionary, key, &directStream)
        }

        if hasDirectStream, let directStream {
            streamData.append(decodedStreamData(from: directStream))
            return streamData
        }

        var streamArray: CGPDFArrayRef?
        let hasStreamArray = "Contents".withCString { key in
            CGPDFDictionaryGetArray(pageDictionary, key, &streamArray)
        }

        guard hasStreamArray, let streamArray else {
            return streamData
        }

        let streamCount = CGPDFArrayGetCount(streamArray)
        for index in 0..<streamCount {
            var stream: CGPDFStreamRef?
            guard CGPDFArrayGetStream(streamArray, index, &stream),
                  let stream else {
                continue
            }

            streamData.append(decodedStreamData(from: stream))
            streamData.append(0x0A)
        }

        return streamData
    }

    private func decodedStreamData(from stream: CGPDFStreamRef) -> Data {
        var dataFormat = CGPDFDataFormat.raw
        guard let rawData = CGPDFStreamCopyData(stream, &dataFormat) as Data? else {
            return Data()
        }

        return rawData
    }

    private func matrixYScaleValues(from contentStreamText: String) -> [Double] {
        let tokens = contentStreamText
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        guard tokens.count >= 7 else {
            return []
        }

        var yScaleValues: [Double] = []
        for index in 6..<tokens.count where tokens[index] == "cm" {
            let dToken = tokens[index - 3]
            if let yScale = Double(dToken) {
                yScaleValues.append(yScale)
            }
        }

        return yScaleValues
    }
}

private extension ModelAndFormattingTests {
    static var analyticsCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "de_DE")
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .gmt
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    func analyticsDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0,
        calendar: Calendar = Self.analyticsCalendar
    ) -> Date {
        calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        ) ?? .distantPast
    }

    func analyticsProjects(
        referenceDate: Date,
        calendar: Calendar
    ) -> [ClientProject] {
        let startOfToday = calendar.startOfDay(for: referenceDate)
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start ?? startOfToday

        let mainProject = ClientProject(
            clientName: "Acme",
            name: "Website",
            hourlyRate: 100
        )
        let supportProject = ClientProject(clientName: "Beta", name: "Support")
        let archivedProject = ClientProject(
            clientName: "Archiv",
            name: "Alt",
            archivedAt: referenceDate
        )

        mainProject.sessions = [
            WorkSession(
                project: mainProject,
                startedAt: startOfToday.addingTimeInterval(-1_800),
                endedAt: startOfToday.addingTimeInterval(1_800)
            ),
            WorkSession(
                project: mainProject,
                startedAt: startOfToday.addingTimeInterval(10 * 3_600),
                endedAt: nil
            ),
            WorkSession(
                project: mainProject,
                startedAt: startOfWeek.addingTimeInterval(-7_200),
                endedAt: startOfWeek.addingTimeInterval(3_600)
            ),
            WorkSession(
                project: mainProject,
                startedAt: analyticsDate(year: 2026, month: 5, day: 3, hour: 9, calendar: calendar),
                endedAt: analyticsDate(year: 2026, month: 5, day: 3, hour: 11, calendar: calendar)
            ),
            WorkSession(
                project: mainProject,
                startedAt: analyticsDate(year: 2026, month: 5, day: 10, hour: 9, calendar: calendar),
                endedAt: analyticsDate(year: 2026, month: 5, day: 10, hour: 11, calendar: calendar)
            ),
            WorkSession(
                project: mainProject,
                startedAt: analyticsDate(year: 2026, month: 2, day: 10, hour: 9, calendar: calendar),
                endedAt: analyticsDate(year: 2026, month: 2, day: 10, hour: 12, calendar: calendar)
            ),
        ]

        supportProject.sessions = [
            WorkSession(
                project: supportProject,
                startedAt: analyticsDate(year: 2026, month: 5, day: 13, hour: 14, calendar: calendar),
                endedAt: analyticsDate(year: 2026, month: 5, day: 13, hour: 15, calendar: calendar)
            ),
            WorkSession(
                project: supportProject,
                startedAt: analyticsDate(year: 2025, month: 12, day: 15, hour: 8, calendar: calendar),
                endedAt: analyticsDate(year: 2025, month: 12, day: 15, hour: 10, calendar: calendar)
            ),
        ]

        archivedProject.sessions = [
            WorkSession(
                project: archivedProject,
                startedAt: startOfToday.addingTimeInterval(8 * 3_600),
                endedAt: startOfToday.addingTimeInterval(9 * 3_600)
            ),
        ]

        return [mainProject, supportProject, archivedProject]
    }
}
