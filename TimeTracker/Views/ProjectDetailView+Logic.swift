import SwiftData
import SwiftUI
import UniformTypeIdentifiers
#if canImport(AppKit)
import AppKit
#endif

extension ProjectDetailView {
    func totalDuration(referenceDate: Date) -> TimeInterval {
        project.sessions.reduce(into: 0) { partialResult, session in
            partialResult += session.duration(referenceDate: referenceDate)
        }
    }
    func todayDuration(referenceDate: Date) -> TimeInterval {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: referenceDate)
        let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? referenceDate

        return project.sessions.reduce(into: 0) { partialResult, session in
            let sessionEnd = session.endedAt ?? referenceDate
            let overlapStart = max(session.startedAt, dayStart)
            let overlapEnd = min(sessionEnd, nextDayStart)

            guard overlapEnd > overlapStart else {
                return
            }

            partialResult += overlapEnd.timeIntervalSince(overlapStart)
        }
    }
    var actionButtonTitle: String {
        if project.isArchived {
            return "Projekt reaktivieren"
        }

        if isActiveProject {
            return "Zeiterfassung stoppen"
        }

        return project.tasks.isEmpty ? "Zeiterfassung starten" : "Ausgewaehlte Aufgabe starten"
    }
    var actionButtonSystemImage: String {
        if project.isArchived {
            return "arrow.uturn.backward.circle.fill"
        }

        return isActiveProject ? "stop.fill" : "play.fill"
    }
    var actionButtonTint: Color {
        if project.isArchived {
            return ClientProject.primaryActionColor
        }

        return isActiveProject ? ClientProject.stopActionColor : project.projectActionColor
    }
    var headerPrimaryStyle: Color {
        colorScheme == .dark ? Color.white.opacity(0.96) : Color.black.opacity(0.9)
    }
    var headerSecondaryStyle: Color {
        colorScheme == .dark ? Color.white.opacity(0.78) : Color.black.opacity(0.62)
    }
    var headerInnerSurfaceStyle: Color {
        colorScheme == .dark ? Color.black.opacity(0.28) : Color.white.opacity(0.72)
    }
    var headerStrokeStyle: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.06)
    }
    var headerShadowStyle: Color {
        colorScheme == .dark ? Color.black.opacity(0.32) : Color.black.opacity(0.05)
    }
    var headerCardGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color.black.opacity(0.30),
                    project.projectAccentColor.opacity(0.34),
                    Color.black.opacity(0.18),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [Color.white.opacity(0.94), project.projectAccentColor.opacity(0.20)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    var pageBackgroundGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    .platformWindowBackground,
                    project.projectAccentColor.opacity(0.16),
                    Color.black.opacity(0.18),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [
                Color(red: 0.95, green: 0.97, blue: 0.98),
                project.projectAccentColor.opacity(0.16),
                Color.white.opacity(0.60),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    var sectionCardGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.07),
                    Color.black.opacity(0.20),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [
                Color.white.opacity(0.98),
                Color(red: 0.95, green: 0.97, blue: 0.995),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    var sectionCardStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.10)
    }
    var sectionCardShadow: Color {
        colorScheme == .dark ? Color.black.opacity(0.14) : Color.black.opacity(0.08)
    }
    var trimmedNewTaskTitle: String {
        newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    var selectedTaskForStart: ProjectTask? {
        if let selectedTaskID,
           let selectedTask = project.tasks.first(where: { $0.id == selectedTaskID }) {
            return selectedTask
        }

        return project.sortedTasks.first
    }
    func syncSelectedTaskForStart() {
        guard !project.sortedTasks.isEmpty else {
            selectedTaskID = nil
            return
        }

        if let selectedTaskID,
           project.tasks.contains(where: { $0.id == selectedTaskID }) {
            return
        }

        selectedTaskID = project.sortedTasks.first?.id
    }
    func selectTaskForStart(_ task: ProjectTask) {
        selectedTaskID = task.id

        guard let runningSession = runningSessionWithoutTask else {
            return
        }

        let previousTask = runningSession.task
        runningSession.task = task

        do {
            try modelContext.save()
        } catch {
            runningSession.task = previousTask
            billingErrorMessage = "Die laufende Zeiterfassung konnte der Aufgabe nicht zugeordnet werden."
        }
    }
    func taskSessionCount(for task: ProjectTask) -> Int {
        project.sessions.filter { $0.task?.id == task.id }.count
    }
    func taskDuration(
        for task: ProjectTask,
        referenceDate: Date
    ) -> TimeInterval {
        duration(for: task.id, referenceDate: referenceDate)
    }
    func duration(
        for taskID: UUID?,
        referenceDate: Date
    ) -> TimeInterval {
        project.sessions.reduce(into: 0) { partialResult, session in
            let sessionTaskID = session.task?.id

            guard sessionTaskID == taskID else {
                return
            }

            partialResult += session.duration(referenceDate: referenceDate)
        }
    }
    func taskValueText(
        for task: ProjectTask,
        referenceDate: Date
    ) -> String {
        valueText(forDuration: taskDuration(for: task, referenceDate: referenceDate))
    }
    func valueText(forDuration duration: TimeInterval) -> String {
        guard let billedAmount = project.billedAmount(for: duration) else {
            return "Offen"
        }

        return TimeFormatting.euroAmount(billedAmount)
    }
    func addTask() {
        guard !trimmedNewTaskTitle.isEmpty else {
            return
        }

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
    func assignSession(
        _ session: WorkSession,
        to task: ProjectTask?
    ) {
        let previousTask = session.task
        session.task = task

        do {
            try modelContext.save()
        } catch {
            session.task = previousTask
            billingErrorMessage = "Die Aufgabe konnte dem Zeiteintrag nicht zugeordnet werden."
        }
    }
    func createTaskAndAssignSession(
        title: String,
        to session: WorkSession
    ) -> Bool {
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
    var parsedHourlyRate: Double? {
        TimeFormatting.parseDecimalInput(hourlyRateText)
    }
    var hasInvalidHourlyRate: Bool {
        let trimmed = hourlyRateText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return false
        }

        guard let parsedHourlyRate else {
            return true
        }

        return parsedHourlyRate < 0
    }
    var hourlyRateHint: String {
        if hasInvalidHourlyRate {
            return "Bitte gib einen gueltigen nicht-negativen Betrag ein."
        }

        return "Leer lassen, wenn das Projekt noch keinen Stundensatz hat."
    }
    var hourlyRateSummary: String {
        guard project.hasHourlyRate else {
            return "Offen"
        }

        return TimeFormatting.euroAmount(project.effectiveHourlyRate)
    }
    var parsedBudgetTarget: Double? {
        TimeFormatting.parseDecimalInput(budgetTargetText)
    }
    var hasInvalidBudgetTarget: Bool {
        let trimmed = budgetTargetText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return false
        }

        guard let parsedBudgetTarget else {
            return true
        }

        return parsedBudgetTarget <= 0
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
    func budgetSummaryValue(referenceDate: Date) -> String {
        guard project.hasBudget else {
            return "Offen"
        }

        return budgetHoursSummary(referenceDate: referenceDate)
    }
    func budgetSummarySubtitle(referenceDate: Date) -> String {
        guard project.hasBudget else {
            return "Wert: Offen"
        }

        return "Wert: \(budgetAmountSummary(referenceDate: referenceDate))"
    }
    func budgetHoursSummary(referenceDate: Date) -> String {
        let duration = totalDuration(referenceDate: referenceDate)
        let consumedHours = project.budgetValue(for: duration, in: .hours) ?? 0
        let consumedText = budgetValueText(consumedHours, unit: .hours)

        guard let targetHours = project.budgetTargetValue(in: .hours) else {
            return consumedText
        }

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

        guard let targetAmount = project.budgetTargetValue(in: .amount) else {
            return consumedText
        }

        return "\(consumedText) / \(budgetValueText(targetAmount, unit: .amount))"
    }
    func secondaryBudgetSummary(
        referenceDate: Date,
        primaryUnit: ProjectBudgetUnit
    ) -> String {
        switch primaryUnit {
        case .hours:
            return "Wert: \(budgetAmountSummary(referenceDate: referenceDate))"
        case .amount:
            return "Zeit: \(budgetHoursSummary(referenceDate: referenceDate))"
        }
    }
    var availableExportModes: [ProjectExportContentMode] {
        if project.hasHourlyRate {
            return ProjectExportContentMode.allCases
        }

        return [.hoursOnly]
    }
    func budgetSnapshot(referenceDate: Date) -> ProjectBudgetSnapshot? {
        guard let unit = project.budgetUnit,
              let target = project.effectiveBudgetTarget else {
            return nil
        }

        let duration = totalDuration(referenceDate: referenceDate)

        guard let consumed = project.budgetConsumedValue(for: duration) else {
            return nil
        }

        return ProjectBudgetSnapshot(
            unit: unit,
            target: target,
            consumed: consumed
        )
    }
    func budgetValueText(
        _ value: Double,
        unit: ProjectBudgetUnit
    ) -> String {
        switch unit {
        case .hours:
            return TimeFormatting.compactDuration(value * 3600)
        case .amount:
            return TimeFormatting.euroAmount(value)
        }
    }
    func convertBudgetEditorValue(
        from oldUnit: ProjectBudgetUnit,
        to newUnit: ProjectBudgetUnit
    ) {
        guard !isSyncingBudgetEditor,
              oldUnit != newUnit,
              let parsedBudgetTarget else {
            return
        }

        guard let convertedBudgetTarget = project.convertedBudgetValue(
            parsedBudgetTarget,
            from: oldUnit,
            to: newUnit
        ) else {
            return
        }

        isSyncingBudgetEditor = true
        budgetTargetText = TimeFormatting.decimalInput(convertedBudgetTarget)
        isSyncingBudgetEditor = false
    }
    var shouldShowBillingCard: Bool {
        !project.hasHourlyRate || isEditingHourlyRate
    }
    var runningSessionWithoutTask: WorkSession? {
        guard isProjectRunningWithoutTask else {
            return nil
        }

        return activeSession
    }
    var billingAlertIsPresented: Binding<Bool> {
        Binding(
            get: { billingErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    billingErrorMessage = nil
                }
            }
        )
    }
    var sessionDeletionIsPresented: Binding<Bool> {
        Binding(
            get: { sessionPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    sessionPendingDeletion = nil
                }
            }
        )
    }
    func totalValueText(referenceDate: Date) -> String {
        guard let billedAmount = project.billedAmount(for: totalDuration(referenceDate: referenceDate)) else {
            return "Offen"
        }

        return TimeFormatting.euroAmount(billedAmount)
    }
    func syncHourlyRateText() {
        hourlyRateText = TimeFormatting.decimalInput(project.hourlyRate)
    }
    func toggleHourlyRateEditing() {
        if project.hasHourlyRate {
            isEditingHourlyRate.toggle()
        } else {
            isEditingHourlyRate = true
        }

        syncHourlyRateText()
    }
    func saveHourlyRate() {
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
    func syncBudgetEditor() {
        isSyncingBudgetEditor = true
        defer { isSyncingBudgetEditor = false }

        selectedBudgetUnit = project.budgetUnit ?? .hours
        budgetTargetText = TimeFormatting.decimalInput(project.effectiveBudgetTarget)
    }
    func syncExportConfiguration() {
        if !project.hasHourlyRate {
            exportContentMode = .hoursOnly
        }

        invalidatePreparedExport()
    }
    var currentExportSelection: ProjectExportSelection {
        ProjectExportSelection.current(
            format: exportFormat,
            selectedMode: exportContentMode,
            hasHourlyRate: project.hasHourlyRate
        )
    }
    var hasPreparedExportForCurrentSelection: Bool {
        guard preparedExportURL != nil else {
            return false
        }

        return preparedExportSelection == currentExportSelection
    }
    func invalidatePreparedExport() {
        preparedExportURL = nil
        preparedExportSelection = nil
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
    func exportProjectData() {
        let selectedMode = currentExportSelection.mode
        let document = ProjectExportService.makeDocument(
            for: project,
            mode: selectedMode,
            referenceDate: .now
        )
        let exportData = ProjectExportService.exportData(
            document: document,
            format: exportFormat
        )

        guard !exportData.isEmpty else {
            billingErrorMessage = "Der Export konnte nicht erstellt werden."
            return
        }

#if os(macOS)
        guard let destinationURL = presentExportSavePanel(for: exportFormat) else {
            return
        }

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
    func presentExportSavePanel(
        for format: ProjectExportFormat
    ) -> URL? {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.allowedContentTypes = [utType(for: format)]
        panel.nameFieldStringValue = defaultExportFileName(for: format)

        let response = panel.runModal()
        guard response == .OK else {
            return nil
        }

        return panel.url
    }
#endif
    func defaultExportFileName(
        for format: ProjectExportFormat
    ) -> String {
        ProjectExportFileNaming.defaultFileName(
            projectName: project.displayName,
            format: format
        )
    }
    func makePreparedExportURL(
        for format: ProjectExportFormat
    ) -> URL {
        URL.temporaryDirectory.appending(path: defaultExportFileName(for: format))
    }

#if os(macOS)
    func utType(for format: ProjectExportFormat) -> UTType {
        switch format {
        case .csv:
            return .commaSeparatedText
        case .pdf:
            return .pdf
        }
    }
#endif
    func saveBudget() {
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
            project.setBudget(
                unit: selectedBudgetUnit,
                target: parsedBudgetTarget
            )
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
    func clearBudget() {
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
    var projectAccentColorBinding: Binding<Color> {
        Binding(
            get: { project.projectAccentColor },
            set: { newColor in
                saveProjectAccentColor(newColor)
            }
        )
    }
    func saveProjectAccentColor(_ color: Color) {
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
    func resetProjectAccentColor() {
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
}

private extension Color {
    static var platformWindowBackground: Color {
#if canImport(AppKit)
        return Color(nsColor: .windowBackgroundColor)
#elseif canImport(UIKit)
        return Color(uiColor: .systemGroupedBackground)
#else
        return .background
#endif
    }
}
