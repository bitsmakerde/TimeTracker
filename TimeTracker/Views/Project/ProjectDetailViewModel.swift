import Foundation
import Observation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
#if canImport(AppKit)
import AppKit
#endif

@MainActor
@Observable
final class ProjectDetailViewModel {
    var project: ClientProject
    var activeSession: WorkSession?

    var hourlyRateText = ""
    var budgetTargetText = ""
    var newTaskTitle = ""
    var selectedBudgetUnit: ProjectBudgetUnit = .hours
    var isEditingHourlyRate = false
    var isPresentingBudgetSheet = false
    var isEditingBudgetInSheet = false
    var isPresentingExportSheet = false
    var exportFormat: ProjectExportFormat = .csv
    var exportContentMode: ProjectExportContentMode = .hoursAndCosts
    var preparedExportURL: URL?
    var preparedExportSelection: ProjectExportSelection?
    var isSyncingBudgetEditor = false
    var billingErrorMessage: String?
    var isConfirmingProjectArchive = false
    var isConfirmingProjectDeletion = false
    var sessionPendingTaskCreation: WorkSession?
    var sessionPendingDeletion: WorkSession?
    var selectedTaskID: UUID?

    init(project: ClientProject, activeSession: WorkSession?) {
        self.project = project
        self.activeSession = activeSession
        syncHourlyRateText()
        syncBudgetEditor()
    }

    func onProjectChanged() {
        syncHourlyRateText()
        syncBudgetEditor()
        syncExportConfiguration()
        isEditingHourlyRate = false
        isPresentingBudgetSheet = false
        isEditingBudgetInSheet = false
        isPresentingExportSheet = false
        syncSelectedTaskForStart()
    }

    // MARK: - Derived State

    var isActiveProject: Bool {
        activeSession?.project?.id == project.id
    }

    var isProjectRunningWithoutTask: Bool {
        guard activeSession?.project?.id == project.id else { return false }
        return activeSession?.task == nil
    }

    var selectedTaskForStart: ProjectTask? {
        ProjectDetailLogic.selectedTaskForStart(project: project, selectedTaskID: selectedTaskID)
    }

    var trimmedNewTaskTitle: String {
        newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var shouldShowBillingCard: Bool {
        !project.hasHourlyRate || isEditingHourlyRate
    }

    var runningSessionWithoutTask: WorkSession? {
        guard isProjectRunningWithoutTask else { return nil }
        return activeSession
    }

    var parsedHourlyRate: Double? {
        ProjectDetailLogic.parsedHourlyRate(from: hourlyRateText)
    }

    var hasInvalidHourlyRate: Bool {
        ProjectDetailLogic.hasInvalidHourlyRate(hourlyRateText)
    }

    var hourlyRateHint: String {
        ProjectDetailLogic.hourlyRateHint(for: hourlyRateText)
    }

    var hourlyRateSummary: String {
        guard project.hasHourlyRate else { return "Offen" }
        return TimeFormatting.euroAmount(project.effectiveHourlyRate)
    }

    var parsedBudgetTarget: Double? {
        ProjectDetailLogic.parsedBudgetTarget(from: budgetTargetText)
    }

    var hasInvalidBudgetTarget: Bool {
        ProjectDetailLogic.hasInvalidBudgetTarget(budgetTargetText)
    }

    var budgetHintText: String {
        if hasInvalidBudgetTarget {
            return "Bitte gib einen gueltigen positiven Wert ein."
        }
        if selectedBudgetUnit == .amount && !project.hasHourlyRate {
            return "Fuer ein EUR-Budget bitte zuerst einen Stundensatz hinterlegen."
        }
        return "Leer lassen, wenn fuer dieses Projekt aktuell kein Budget gelten soll."
    }

    var availableExportModes: [ProjectExportContentMode] {
        ProjectDetailLogic.availableExportModes(hasHourlyRate: project.hasHourlyRate)
    }

    var currentExportSelection: ProjectExportSelection {
        ProjectDetailLogic.currentExportSelection(
            format: exportFormat,
            selectedMode: exportContentMode,
            project: project
        )
    }

    var hasPreparedExportForCurrentSelection: Bool {
        ProjectDetailLogic.hasPreparedExport(
            preparedURL: preparedExportURL,
            preparedSelection: preparedExportSelection,
            currentSelection: currentExportSelection
        )
    }

    var billingAlertIsPresented: Binding<Bool> {
        Binding(
            get: { self.billingErrorMessage != nil },
            set: { isPresented in
                self.billingErrorMessage = ProjectDetailLogic.alertMessageAfterPresentationChange(
                    currentMessage: self.billingErrorMessage,
                    isPresented: isPresented
                )
            }
        )
    }

    var sessionDeletionIsPresented: Binding<Bool> {
        Binding(
            get: { self.sessionPendingDeletion != nil },
            set: { isPresented in
                self.sessionPendingDeletion = ProjectDetailLogic.pendingSessionAfterDeletionPresentationChange(
                    currentSession: self.sessionPendingDeletion,
                    isPresented: isPresented
                )
            }
        )
    }

    var actionButtonTitle: String {
        if project.isArchived { return "Projekt reaktivieren" }
        if isActiveProject { return "Zeiterfassung stoppen" }
        return project.taskList.isEmpty ? "Zeiterfassung starten" : "Ausgewaehlte Aufgabe starten"
    }

    var actionButtonSystemImage: String {
        if project.isArchived { return "arrow.uturn.backward.circle.fill" }
        return isActiveProject ? "stop.fill" : "play.fill"
    }

    var actionButtonTint: Color {
        if project.isArchived { return ClientProject.primaryActionColor }
        return isActiveProject ? ClientProject.stopActionColor : project.projectActionColor
    }

    // MARK: - Sync

    func syncHourlyRateText() {
        hourlyRateText = ProjectDetailLogic.hourlyRateText(for: project)
    }

    func syncBudgetEditor() {
        isSyncingBudgetEditor = true
        defer { isSyncingBudgetEditor = false }
        selectedBudgetUnit = ProjectDetailLogic.budgetUnit(for: project)
        budgetTargetText = ProjectDetailLogic.budgetTargetText(for: project)
    }

    func syncExportConfiguration() {
        if !project.hasHourlyRate {
            exportContentMode = ProjectDetailLogic.normalizedExportContentMode(
                selectedMode: exportContentMode,
                hasHourlyRate: false
            )
        }
        invalidatePreparedExport()
    }

    func syncSelectedTaskForStart() {
        selectedTaskID = ProjectDetailLogic.synchronizedSelectedTaskID(
            project: project,
            selectedTaskID: selectedTaskID
        )
    }

    func invalidatePreparedExport() {
        preparedExportURL = nil
        preparedExportSelection = nil
    }

    func toggleHourlyRateEditing() {
        isEditingHourlyRate = ProjectDetailLogic.toggledHourlyRateEditing(
            currentlyEditing: isEditingHourlyRate,
            hasHourlyRate: project.hasHourlyRate
        )
        syncHourlyRateText()
    }

    func convertBudgetEditorValue(from oldUnit: ProjectBudgetUnit, to newUnit: ProjectBudgetUnit) {
        guard !isSyncingBudgetEditor,
              let converted = ProjectDetailLogic.convertedBudgetEditorText(
                budgetTargetText, project: project, from: oldUnit, to: newUnit
              ) else { return }
        isSyncingBudgetEditor = true
        budgetTargetText = converted
        isSyncingBudgetEditor = false
    }

    func presentBudgetDetails() {
        syncBudgetEditor()
        isEditingBudgetInSheet = false
        isPresentingBudgetSheet = true
    }

    func presentProjectExportSheet() {
        syncExportConfiguration()
        isPresentingExportSheet = true
    }

    // MARK: - Duration & Budget Computations

    func totalDuration(referenceDate: Date) -> TimeInterval {
        project.sessionList.reduce(into: 0) { $0 += $1.duration(referenceDate: referenceDate) }
    }

    func todayDuration(referenceDate: Date) -> TimeInterval {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: referenceDate)
        let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? referenceDate
        return project.sessionList.reduce(into: 0) { partialResult, session in
            let sessionEnd = session.endedAt ?? referenceDate
            let overlapStart = max(session.startedAt, dayStart)
            let overlapEnd = min(sessionEnd, nextDayStart)
            guard overlapEnd > overlapStart else { return }
            partialResult += overlapEnd.timeIntervalSince(overlapStart)
        }
    }

    func totalValueText(referenceDate: Date) -> String {
        guard let billedAmount = project.billedAmount(for: totalDuration(referenceDate: referenceDate)) else {
            return "Offen"
        }
        return TimeFormatting.euroAmount(billedAmount)
    }

    func taskSessionCount(for task: ProjectTask) -> Int {
        project.sessionList.filter { $0.task?.id == task.id }.count
    }

    func taskDuration(for task: ProjectTask, referenceDate: Date) -> TimeInterval {
        duration(for: task.id, referenceDate: referenceDate)
    }

    func duration(for taskID: UUID?, referenceDate: Date) -> TimeInterval {
        project.sessionList.reduce(into: 0) { partialResult, session in
            guard session.task?.id == taskID else { return }
            partialResult += session.duration(referenceDate: referenceDate)
        }
    }

    func taskValueText(for task: ProjectTask, referenceDate: Date) -> String {
        valueText(forDuration: taskDuration(for: task, referenceDate: referenceDate))
    }

    func valueText(forDuration duration: TimeInterval) -> String {
        guard let billedAmount = project.billedAmount(for: duration) else { return "Offen" }
        return TimeFormatting.euroAmount(billedAmount)
    }

    func budgetSnapshot(referenceDate: Date) -> ProjectBudgetSnapshot? {
        guard let unit = project.budgetUnit,
              let target = project.effectiveBudgetTarget else { return nil }
        let duration = totalDuration(referenceDate: referenceDate)
        guard let consumed = project.budgetConsumedValue(for: duration) else { return nil }
        return ProjectBudgetSnapshot(unit: unit, target: target, consumed: consumed)
    }

    func budgetValueText(_ value: Double, unit: ProjectBudgetUnit) -> String {
        switch unit {
        case .hours: return TimeFormatting.compactDuration(value * 3600)
        case .amount: return TimeFormatting.euroAmount(value)
        }
    }

    func budgetSummaryValue(referenceDate: Date) -> String {
        guard project.hasBudget else { return "Offen" }
        return budgetHoursSummary(referenceDate: referenceDate)
    }

    func budgetSummarySubtitle(referenceDate: Date) -> String {
        guard project.hasBudget else { return "Wert: Offen" }
        return "Wert: \(budgetAmountSummary(referenceDate: referenceDate))"
    }

    func budgetHoursSummary(referenceDate: Date) -> String {
        let duration = totalDuration(referenceDate: referenceDate)
        let consumedHours = project.budgetValue(for: duration, in: .hours) ?? 0
        let consumedText = budgetValueText(consumedHours, unit: .hours)
        guard let targetHours = project.budgetTargetValue(in: .hours) else { return consumedText }
        return "\(consumedText) / \(budgetValueText(targetHours, unit: .hours))"
    }

    func budgetAmountSummary(referenceDate: Date) -> String {
        let duration = totalDuration(referenceDate: referenceDate)
        let consumedText: String
        if let consumedAmount = project.budgetValue(for: duration, in: .amount) {
            consumedText = budgetValueText(consumedAmount, unit: .amount)
        } else {
            consumedText = "Offen"
        }
        guard let targetAmount = project.budgetTargetValue(in: .amount) else { return consumedText }
        return "\(consumedText) / \(budgetValueText(targetAmount, unit: .amount))"
    }

    func secondaryBudgetSummary(referenceDate: Date, primaryUnit: ProjectBudgetUnit) -> String {
        switch primaryUnit {
        case .hours: return "Wert: \(budgetAmountSummary(referenceDate: referenceDate))"
        case .amount: return "Zeit: \(budgetHoursSummary(referenceDate: referenceDate))"
        }
    }

    // MARK: - Mutations

    func selectTaskForStart(_ task: ProjectTask, modelContext: ModelContext) {
        selectedTaskID = task.id
        guard let runningSession = runningSessionWithoutTask else { return }
        let previousTask = runningSession.task
        runningSession.task = task
        do {
            try modelContext.save()
        } catch {
            runningSession.task = previousTask
            billingErrorMessage = "Die laufende Zeiterfassung konnte der Aufgabe nicht zugeordnet werden."
        }
    }

    func addTask(modelContext: ModelContext) {
        guard !trimmedNewTaskTitle.isEmpty else { return }
        let task = ProjectTask(title: trimmedNewTaskTitle, project: project)
        modelContext.insert(task)
        let runningSession = runningSessionWithoutTask
        let previousTask = runningSession?.task
        runningSession?.task = task
        do {
            try modelContext.save()
            newTaskTitle = ""
            selectedTaskID = task.id
        } catch {
            runningSession?.task = previousTask
            modelContext.delete(task)
            billingErrorMessage = "Die Aufgabe konnte nicht gespeichert werden."
        }
    }

    func assignSession(_ session: WorkSession, to task: ProjectTask?, modelContext: ModelContext) {
        let previousTask = session.task
        session.task = task
        do {
            try modelContext.save()
        } catch {
            session.task = previousTask
            billingErrorMessage = "Die Aufgabe konnte dem Zeiteintrag nicht zugeordnet werden."
        }
    }

    @discardableResult
    func createTaskAndAssignSession(title: String, to session: WorkSession, modelContext: ModelContext) -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            billingErrorMessage = "Bitte gib einen gueltigen Aufgabentitel ein."
            return false
        }
        let previousTask = session.task
        let task = ProjectTask(title: trimmedTitle, project: project)
        modelContext.insert(task)
        session.task = task
        do {
            try modelContext.save()
            return true
        } catch {
            session.task = previousTask
            modelContext.delete(task)
            billingErrorMessage = "Die Aufgabe konnte nicht erstellt und zugeordnet werden."
            return false
        }
    }

    func saveHourlyRate(modelContext: ModelContext) {
        guard !hasInvalidHourlyRate else {
            billingErrorMessage = "Der Stundensatz ist ungueltig."
            return
        }
        let previousHourlyRate = project.hourlyRate
        project.hourlyRate = parsedHourlyRate
        do {
            try modelContext.save()
            syncHourlyRateText()
            isEditingHourlyRate = false
        } catch {
            project.hourlyRate = previousHourlyRate
            billingErrorMessage = "Der Stundensatz konnte nicht gespeichert werden."
        }
    }

    func saveBudget(modelContext: ModelContext) {
        guard !hasInvalidBudgetTarget else {
            billingErrorMessage = "Das Budget ist ungueltig."
            return
        }
        if selectedBudgetUnit == .amount && !project.hasHourlyRate {
            billingErrorMessage = "Fuer ein EUR-Budget wird ein Stundensatz benoetigt."
            return
        }
        let previousBudgetUnitRaw = project.budgetUnitRaw
        let previousBudgetTarget = project.budgetTarget
        if let parsedBudgetTarget {
            project.setBudget(unit: selectedBudgetUnit, target: parsedBudgetTarget)
        } else {
            project.clearBudget()
        }
        do {
            try modelContext.save()
            syncBudgetEditor()
        } catch {
            project.budgetUnitRaw = previousBudgetUnitRaw
            project.budgetTarget = previousBudgetTarget
            billingErrorMessage = "Das Budget konnte nicht gespeichert werden."
        }
    }

    func clearBudget(modelContext: ModelContext) {
        let previousBudgetUnitRaw = project.budgetUnitRaw
        let previousBudgetTarget = project.budgetTarget
        project.clearBudget()
        do {
            try modelContext.save()
            syncBudgetEditor()
        } catch {
            project.budgetUnitRaw = previousBudgetUnitRaw
            project.budgetTarget = previousBudgetTarget
            billingErrorMessage = "Das Budget konnte nicht entfernt werden."
        }
    }

    func saveProjectAccentColor(_ color: Color, modelContext: ModelContext) {
        let previousRed = project.accentRed
        let previousGreen = project.accentGreen
        let previousBlue = project.accentBlue
        project.setCustomAccentColor(color)
        do {
            try modelContext.save()
        } catch {
            project.accentRed = previousRed
            project.accentGreen = previousGreen
            project.accentBlue = previousBlue
            billingErrorMessage = "Die Projektfarbe konnte nicht gespeichert werden."
        }
    }

    func resetProjectAccentColor(modelContext: ModelContext) {
        let previousRed = project.accentRed
        let previousGreen = project.accentGreen
        let previousBlue = project.accentBlue
        project.clearCustomAccentColor()
        do {
            try modelContext.save()
        } catch {
            project.accentRed = previousRed
            project.accentGreen = previousGreen
            project.accentBlue = previousBlue
            billingErrorMessage = "Die Projektfarbe konnte nicht zurueckgesetzt werden."
        }
    }

    // MARK: - Export

    func exportProjectData() {
        let selectedMode = currentExportSelection.mode
        let document = ProjectExportService.makeDocument(
            for: project,
            mode: selectedMode,
            referenceDate: .now
        )
        let exportData = ProjectExportService.exportData(document: document, format: exportFormat)
        guard !exportData.isEmpty else {
            billingErrorMessage = "Der Export konnte nicht erstellt werden."
            return
        }

#if os(macOS)
        guard let destinationURL = presentExportSavePanel(for: exportFormat) else { return }
        do {
            try exportData.write(to: destinationURL, options: .atomic)
            isPresentingExportSheet = false
        } catch {
            billingErrorMessage = "Die Exportdatei konnte nicht gespeichert werden."
        }
#else
        let destinationURL = makePreparedExportURL(for: currentExportSelection.format)
        do {
            try exportData.write(to: destinationURL, options: .atomic)
            preparedExportURL = destinationURL
            preparedExportSelection = currentExportSelection
        } catch {
            billingErrorMessage = "Die Exportdatei konnte nicht vorbereitet werden."
            invalidatePreparedExport()
        }
#endif
    }

#if os(macOS)
    func presentExportSavePanel(for format: ProjectExportFormat) -> URL? {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.allowedContentTypes = [utType(for: format)]
        panel.nameFieldStringValue = defaultExportFileName(for: format)
        let response = panel.runModal()
        guard response == .OK else { return nil }
        return panel.url
    }

    func utType(for format: ProjectExportFormat) -> UTType {
        switch format {
        case .csv: return .commaSeparatedText
        case .pdf: return .pdf
        }
    }
#endif

    func defaultExportFileName(for format: ProjectExportFormat) -> String {
        ProjectExportFileNaming.defaultFileName(projectName: project.displayName, format: format)
    }

    func makePreparedExportURL(for format: ProjectExportFormat) -> URL {
        URL.temporaryDirectory.appending(path: defaultExportFileName(for: format))
    }
}
