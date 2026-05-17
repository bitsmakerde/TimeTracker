import SwiftData
import SwiftUI
import UniformTypeIdentifiers
#if canImport(AppKit)
import AppKit
#endif

enum ProjectDetailLogic {
    static func selectedTaskForStart(
        project: ClientProject,
        selectedTaskID: UUID?
    ) -> ProjectTask? {
        if let selectedTaskID,
           let selectedTask = project.taskList.first(where: { $0.id == selectedTaskID }) {
            return selectedTask
        }

        return project.sortedTasks.first
    }

    static func synchronizedSelectedTaskID(
        project: ClientProject,
        selectedTaskID: UUID?
    ) -> UUID? {
        guard !project.sortedTasks.isEmpty else {
            return nil
        }

        if let selectedTaskID,
           project.taskList.contains(where: { $0.id == selectedTaskID }) {
            return selectedTaskID
        }

        return project.sortedTasks.first?.id
    }

    static func hourlyRateText(for project: ClientProject) -> String {
        TimeFormatting.decimalInput(project.hourlyRate)
    }

    static func parsedHourlyRate(from text: String) -> Double? {
        TimeFormatting.parseDecimalInput(text)
    }

    static func hasInvalidHourlyRate(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return false
        }

        guard let parsedHourlyRate = parsedHourlyRate(from: text) else {
            return true
        }

        return parsedHourlyRate < 0
    }

    static func hourlyRateHint(for text: String) -> String {
        if hasInvalidHourlyRate(text) {
            return "Bitte gib einen gueltigen nicht-negativen Betrag ein."
        }

        return "Leer lassen, wenn das Projekt noch keinen Stundensatz hat."
    }

    static func toggledHourlyRateEditing(
        currentlyEditing: Bool,
        hasHourlyRate: Bool
    ) -> Bool {
        hasHourlyRate ? !currentlyEditing : true
    }

    static func budgetUnit(for project: ClientProject) -> ProjectBudgetUnit {
        project.budgetUnit ?? .hours
    }

    static func budgetTargetText(for project: ClientProject) -> String {
        TimeFormatting.decimalInput(project.effectiveBudgetTarget)
    }

    static func parsedBudgetTarget(from text: String) -> Double? {
        TimeFormatting.parseDecimalInput(text)
    }

    static func hasInvalidBudgetTarget(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return false
        }

        guard let parsedBudgetTarget = parsedBudgetTarget(from: text) else {
            return true
        }

        return parsedBudgetTarget <= 0
    }

    static func convertedBudgetEditorText(
        _ text: String,
        project: ClientProject,
        from oldUnit: ProjectBudgetUnit,
        to newUnit: ProjectBudgetUnit
    ) -> String? {
        guard oldUnit != newUnit,
              let parsedBudgetTarget = parsedBudgetTarget(from: text),
              let convertedBudgetTarget = project.convertedBudgetValue(
                parsedBudgetTarget,
                from: oldUnit,
                to: newUnit
              ) else {
            return nil
        }

        return TimeFormatting.decimalInput(convertedBudgetTarget)
    }

    static func availableExportModes(hasHourlyRate: Bool) -> [ProjectExportContentMode] {
        hasHourlyRate ? ProjectExportContentMode.allCases : [.hoursOnly]
    }

    static func normalizedExportContentMode(
        selectedMode: ProjectExportContentMode,
        hasHourlyRate: Bool
    ) -> ProjectExportContentMode {
        hasHourlyRate ? selectedMode : .hoursOnly
    }

    static func currentExportSelection(
        format: ProjectExportFormat,
        selectedMode: ProjectExportContentMode,
        project: ClientProject
    ) -> ProjectExportSelection {
        ProjectExportSelection.current(
            format: format,
            selectedMode: selectedMode,
            hasHourlyRate: project.hasHourlyRate
        )
    }

    static func hasPreparedExport(
        preparedURL: URL?,
        preparedSelection: ProjectExportSelection?,
        currentSelection: ProjectExportSelection
    ) -> Bool {
        guard preparedURL != nil else {
            return false
        }

        return preparedSelection == currentSelection
    }

    static func alertMessageAfterPresentationChange(
        currentMessage: String?,
        isPresented: Bool
    ) -> String? {
        isPresented ? currentMessage : nil
    }

    static func pendingSessionAfterDeletionPresentationChange(
        currentSession: WorkSession?,
        isPresented: Bool
    ) -> WorkSession? {
        isPresented ? currentSession : nil
    }

    static func pendingTaskAfterDeletionPresentationChange(
        currentTask: ProjectTask?,
        isPresented: Bool
    ) -> ProjectTask? {
        isPresented ? currentTask : nil
    }

    static func pendingSessionAfterEditorPresentationChange(
        currentSession: WorkSession?,
        isPresented: Bool
    ) -> WorkSession? {
        isPresented ? currentSession : nil
    }

    static func taskEditorEntrySaveErrorMessage(isEditing: Bool) -> String {
        isEditing
            ? "Der Zeiteintrag konnte nicht aktualisiert werden."
            : "Der Zeiteintrag konnte nicht gespeichert werden."
    }

    static func taskEditorTaskDeleteErrorMessage() -> String {
        "Die Aufgabe konnte nicht entfernt werden."
    }

    static func taskEditorSessions(for task: ProjectTask) -> [WorkSession] {
        task.sessionList.sorted { lhs, rhs in
            if lhs.startedAt == rhs.startedAt {
                return lhs.id.uuidString < rhs.id.uuidString
            }

            return lhs.startedAt > rhs.startedAt
        }
    }

    static func normalizedTaskTitle(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func taskTitleValidationMessage(_ title: String) -> String? {
        normalizedTaskTitle(title).isEmpty
            ? "Bitte gib einen gueltigen Aufgabentitel ein."
            : nil
    }
}
