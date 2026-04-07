import SwiftData
import SwiftUI
import Charts
import UniformTypeIdentifiers
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

struct ProjectDetailLayoutMetrics {
    static func contentPadding(horizontalSizeClass: UserInterfaceSizeClass?) -> CGFloat {
        horizontalSizeClass == .compact ? 16 : 24
    }

    static func sectionPadding(horizontalSizeClass: UserInterfaceSizeClass?) -> CGFloat {
        horizontalSizeClass == .compact ? 16 : 24
    }

    static func summaryGridMinimum(horizontalSizeClass: UserInterfaceSizeClass?) -> CGFloat {
        horizontalSizeClass == .compact ? 140 : 180
    }

    static func usesStackedRow(
        dynamicTypeSize: DynamicTypeSize,
        horizontalSizeClass: UserInterfaceSizeClass?
    ) -> Bool {
        if horizontalSizeClass == .compact {
            return true
        }

        return dynamicTypeSize >= .accessibility1
    }

    static func sessionRowSpacing(
        dynamicTypeSize: DynamicTypeSize,
        horizontalSizeClass: UserInterfaceSizeClass?
    ) -> CGFloat {
        usesStackedRow(
            dynamicTypeSize: dynamicTypeSize,
            horizontalSizeClass: horizontalSizeClass
        ) ? 10 : 12
    }

    static func sessionRowPadding(
        dynamicTypeSize: DynamicTypeSize,
        horizontalSizeClass: UserInterfaceSizeClass?
    ) -> CGFloat {
        usesStackedRow(
            dynamicTypeSize: dynamicTypeSize,
            horizontalSizeClass: horizontalSizeClass
        ) ? 12 : 18
    }
}

struct ProjectExportSelection: Equatable {
    let format: ProjectExportFormat
    let mode: ProjectExportContentMode

    static func current(
        format: ProjectExportFormat,
        selectedMode: ProjectExportContentMode,
        hasHourlyRate: Bool
    ) -> ProjectExportSelection {
        let mode: ProjectExportContentMode = hasHourlyRate ? selectedMode : .hoursOnly
        return ProjectExportSelection(format: format, mode: mode)
    }
}

struct ProjectDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let project: ClientProject
    let activeSession: WorkSession?
    let onStart: () -> Void
    let onStartTask: (ProjectTask) -> Void
    let onStop: () -> Void
    let onAddManualEntry: () -> Void
    let onEditSession: (WorkSession) -> Void
    let onDeleteSession: (WorkSession) -> Void
    let onArchiveProject: () -> Void
    let onRestoreProject: () -> Void
    let onDeleteProject: () -> Void

    @State private var hourlyRateText = ""
    @State private var budgetTargetText = ""
    @State private var newTaskTitle = ""
    @State private var selectedBudgetUnit: ProjectBudgetUnit = .hours
    @State private var isEditingHourlyRate = false
    @State private var isPresentingBudgetSheet = false
    @State private var isEditingBudgetInSheet = false
    @State private var isPresentingExportSheet = false
    @State private var exportFormat: ProjectExportFormat = .csv
    @State private var exportContentMode: ProjectExportContentMode = .hoursAndCosts
    @State private var preparedExportURL: URL?
    @State private var preparedExportSelection: ProjectExportSelection?
    @State private var isSyncingBudgetEditor = false
    @State private var billingErrorMessage: String?
    @State private var isConfirmingProjectArchive = false
    @State private var isConfirmingProjectDeletion = false
    @State private var sessionPendingTaskCreation: WorkSession?
    @State private var sessionPendingDeletion: WorkSession?
    @State private var selectedTaskID: UUID?

    private var isActiveProject: Bool {
        activeSession?.project?.id == project.id
    }

    private var isProjectRunningWithoutTask: Bool {
        guard activeSession?.project?.id == project.id else {
            return false
        }

        return activeSession?.task == nil
    }

    private var isCompactWidth: Bool {
        horizontalSizeClass == .compact
    }

    private var contentPadding: CGFloat {
        ProjectDetailLayoutMetrics.contentPadding(horizontalSizeClass: horizontalSizeClass)
    }

    private var sectionPadding: CGFloat {
        ProjectDetailLayoutMetrics.sectionPadding(horizontalSizeClass: horizontalSizeClass)
    }

    private var summaryGridMinimum: CGFloat {
        ProjectDetailLayoutMetrics.summaryGridMinimum(horizontalSizeClass: horizontalSizeClass)
    }

    private var usesStackedRows: Bool {
        ProjectDetailLayoutMetrics.usesStackedRow(
            dynamicTypeSize: dynamicTypeSize,
            horizontalSizeClass: horizontalSizeClass
        )
    }

    private var sectionCornerRadius: CGFloat {
        isCompactWidth ? 22 : 28
    }

    private var headerCornerRadius: CGFloat {
        isCompactWidth ? 24 : 30
    }

    var body: some View {
        ZStack {
            pageBackgroundGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerCard

                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        summaryRow(referenceDate: timeline.date)
                    }

                    if shouldShowBillingCard {
                        billingCard
                    }

                    tasksCard

                    sessionsCard
                }
                .padding(contentPadding)
            }
        }
        .onAppear {
            syncHourlyRateText()
            syncBudgetEditor()
            syncExportConfiguration()
            syncSelectedTaskForStart()
        }
        .onChange(of: project.id) { _, _ in
            syncHourlyRateText()
            syncBudgetEditor()
            syncExportConfiguration()
            isEditingHourlyRate = false
            isPresentingBudgetSheet = false
            isEditingBudgetInSheet = false
            isPresentingExportSheet = false
            syncSelectedTaskForStart()
        }
        .onChange(of: project.sortedTasks.map(\.id)) { _, _ in
            syncSelectedTaskForStart()
        }
        .onChange(of: exportFormat) { _, _ in
            invalidatePreparedExport()
        }
        .onChange(of: exportContentMode) { _, _ in
            invalidatePreparedExport()
        }
        .onChange(of: selectedBudgetUnit) { oldUnit, newUnit in
            convertBudgetEditorValue(from: oldUnit, to: newUnit)
        }
        .onChange(of: isPresentingBudgetSheet) { _, isPresented in
            if !isPresented {
                isEditingBudgetInSheet = false
            }
        }
        .alert("Speichern fehlgeschlagen", isPresented: billingAlertIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(billingErrorMessage ?? "")
        }
        .confirmationDialog(
            "Projekt abschliessen?",
            isPresented: $isConfirmingProjectArchive,
            titleVisibility: .visible
        ) {
            Button("Projekt archivieren", role: .destructive, action: onArchiveProject)
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Das Projekt wird ins Archiv verschoben und nicht mehr bei den aktiven Kundenprojekten angezeigt.")
        }
        .confirmationDialog(
            "Projekt loeschen?",
            isPresented: $isConfirmingProjectDeletion,
            titleVisibility: .visible
        ) {
            Button("Projekt loeschen", role: .destructive, action: onDeleteProject)
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Das Projekt und alle zugehoerigen Zeiteintraege werden dauerhaft geloescht.")
        }
        .confirmationDialog(
            "Zeiteintrag loeschen?",
            isPresented: sessionDeletionIsPresented,
            titleVisibility: .visible
        ) {
            if let sessionPendingDeletion {
                Button("Zeiteintrag loeschen", role: .destructive) {
                    onDeleteSession(sessionPendingDeletion)
                    self.sessionPendingDeletion = nil
                }
            }

            Button("Abbrechen", role: .cancel) {
                sessionPendingDeletion = nil
            }
        } message: {
            if let sessionPendingDeletion {
                Text("Der Eintrag vom \(TimeFormatting.shortDate(sessionPendingDeletion.startedAt)) wird dauerhaft geloescht.")
            }
        }
        .sheet(item: $sessionPendingTaskCreation) { session in
            NewTaskAssignmentSheet(
                project: project,
                session: session
            ) { title in
                createTaskAndAssignSession(
                    title: title,
                    to: session
                )
            }
        }
        .sheet(isPresented: $isPresentingBudgetSheet) {
            budgetSheet
        }
        .sheet(isPresented: $isPresentingExportSheet) {
            projectExportSheet
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: isCompactWidth ? 16 : 20) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 20) {
                    headerPrimaryInfo
                    Spacer()
                    headerActionPanel(alignment: .trailing)
                }

                VStack(alignment: .leading, spacing: 16) {
                    headerPrimaryInfo
                    headerActionPanel(alignment: .leading)
                }
            }

            if let archivedAt = project.archivedAt {
                archiveStatusBadge(archivedAt: archivedAt)
            }

            if isActiveProject, let activeSession {
                HStack(spacing: 12) {
                    Image(systemName: "timer")
                        .foregroundStyle(project.projectAccentColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(activeSession.displayTaskTitle)
                            .font(.subheadline)
                            .bold()
                            .foregroundStyle(headerSecondaryStyle)

                        TimelineView(.periodic(from: .now, by: 1)) { timeline in
                            Text("Laeuft seit \(TimeFormatting.shortTime(activeSession.startedAt)) - \(TimeFormatting.digitalDuration(activeSession.duration(referenceDate: timeline.date)))")
                                .font(.headline)
                                .monospacedDigit()
                                .foregroundStyle(headerPrimaryStyle)
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(headerInnerSurfaceStyle)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(headerStrokeStyle, lineWidth: 1)
                )
            }
        }
        .padding(sectionPadding)
        .background(
            RoundedRectangle(cornerRadius: headerCornerRadius, style: .continuous)
                .fill(headerCardGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: headerCornerRadius, style: .continuous)
                .stroke(headerStrokeStyle, lineWidth: 1)
        )
        .shadow(color: headerShadowStyle, radius: 18, x: 0, y: 12)
    }

    private var headerPrimaryInfo: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Circle()
                    .fill(project.projectAccentColor)
                    .frame(width: 14, height: 14)

                Text(project.displayName)
                    .font(.largeTitle)
                    .bold()
                    .foregroundStyle(headerPrimaryStyle)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(project.displayClientName)
                .font(.title3)
                .foregroundStyle(headerSecondaryStyle)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            if !project.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(project.notes)
                    .font(.body)
                    .foregroundStyle(headerSecondaryStyle)
                    .padding(.top, 2)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func headerActionPanel(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 10) {
            actionButton
            if !project.isArchived {
                manualEntryButton
            }
            projectActionsButton
            projectColorControls

            if !project.isArchived, let selectedTaskForStart {
                Label("Aktiv: \(selectedTaskForStart.displayTitle)", systemImage: "scope")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(headerSecondaryStyle)
                    .frame(maxWidth: isCompactWidth ? .infinity : 260, alignment: isCompactWidth ? .leading : .trailing)
                    .multilineTextAlignment(isCompactWidth ? .leading : .trailing)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !project.isArchived,
               let activeSession,
               let activeProject = activeSession.project,
               activeProject.id != project.id {
                Text("Beim Start wird \(activeProject.displayName) automatisch gestoppt.")
                    .font(.caption)
                    .foregroundStyle(headerSecondaryStyle)
                    .frame(maxWidth: isCompactWidth ? .infinity : 260, alignment: isCompactWidth ? .leading : .trailing)
                    .multilineTextAlignment(isCompactWidth ? .leading : .trailing)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: isCompactWidth ? .infinity : nil, alignment: isCompactWidth ? .leading : .trailing)
    }

    private var actionButton: some View {
        Button(action: {
            if project.isArchived {
                onRestoreProject()
            } else if isActiveProject {
                onStop()
            } else if let selectedTaskForStart {
                onStartTask(selectedTaskForStart)
            } else {
                onStart()
            }
        }) {
            Label(
                actionButtonTitle,
                systemImage: actionButtonSystemImage
            )
            .frame(minWidth: isCompactWidth ? nil : 220)
            .frame(maxWidth: isCompactWidth ? .infinity : nil)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(actionButtonTint)
    }

    private var projectActionsButton: some View {
        Menu {
            if project.isArchived {
                Button(action: onRestoreProject) {
                    Label("Projekt reaktivieren", systemImage: "arrow.uturn.backward.circle")
                }
            } else {
                Button {
                    isConfirmingProjectArchive = true
                } label: {
                    Label("Projekt abschliessen", systemImage: "archivebox.fill")
                }
            }

            Divider()

            Button(action: presentProjectExportSheet) {
                Label("Projekt exportieren", systemImage: "square.and.arrow.up")
            }

            Divider()

            Button(role: .destructive) {
                isConfirmingProjectDeletion = true
            } label: {
                Label("Projekt loeschen", systemImage: "trash")
            }
        } label: {
            Label("Projekt", systemImage: "ellipsis.circle")
                .frame(minWidth: isCompactWidth ? nil : 220)
                .frame(maxWidth: isCompactWidth ? .infinity : nil)
        }
#if os(macOS)
        .menuStyle(.borderlessButton)
#endif
        .controlSize(.large)
    }

    private var projectColorControls: some View {
        HStack(spacing: 10) {
            Text("Farbe")
                .font(.caption)
                .bold()
                .foregroundStyle(headerSecondaryStyle)

            ColorPicker(
                "Projektfarbe",
                selection: projectAccentColorBinding,
                supportsOpacity: false
            )
            .labelsHidden()
            .controlSize(.small)

            if project.hasCustomAccentColor {
                Button("Auto", action: resetProjectAccentColor)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: isCompactWidth ? .infinity : 260, alignment: isCompactWidth ? .leading : .trailing)
    }

    private func archiveStatusBadge(archivedAt: Date) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "archivebox.fill")
                .foregroundStyle(headerSecondaryStyle)

            Text("Archiviert am \(TimeFormatting.shortDate(archivedAt))")
                .font(.headline)
                .foregroundStyle(headerSecondaryStyle)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(headerInnerSurfaceStyle)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(headerStrokeStyle, lineWidth: 1)
        )
    }

    private var billingCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(project.hasHourlyRate ? "Stundensatz bearbeiten" : "Stundensatz hinterlegen")
                    .font(.title2)
                    .bold()
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                if project.hasHourlyRate {
                    Button("Schliessen") {
                        isEditingHourlyRate = false
                        syncHourlyRateText()
                    }
                    .buttonStyle(.bordered)
                }
            }

            if usesStackedRows {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Stundensatz")
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(.secondary)

                    TextField("z. B. 95,00", text: $hourlyRateText)
                        .textFieldStyle(.roundedBorder)

                    Text("EUR pro Stunde")
                        .foregroundStyle(.secondary)

                    Text(hourlyRateHint)
                        .font(.caption)
                        .foregroundStyle(hasInvalidHourlyRate ? .red : .secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)

                    Button("Stundensatz speichern", action: saveHourlyRate)
                        .buttonStyle(.borderedProminent)
                        .tint(project.projectActionColor)
                        .disabled(hasInvalidHourlyRate)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Aktueller Satz")
                            .font(.caption)
                            .bold()
                            .foregroundStyle(.secondary)

                        Text(hourlyRateSummary)
                            .font(.title2)
                            .bold()
                            .monospacedDigit()
                    }
                }
            } else {
                HStack(alignment: .center, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Stundensatz")
                            .font(.subheadline)
                            .bold()
                            .foregroundStyle(.secondary)

                        HStack(spacing: 10) {
                            TextField("z. B. 95,00", text: $hourlyRateText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 160)

                            Text("EUR pro Stunde")
                                .foregroundStyle(.secondary)
                        }

                        Text(hourlyRateHint)
                            .font(.caption)
                            .foregroundStyle(hasInvalidHourlyRate ? .red : .secondary)
                    }

                    Button("Stundensatz speichern", action: saveHourlyRate)
                        .buttonStyle(.borderedProminent)
                        .tint(project.projectActionColor)
                        .disabled(hasInvalidHourlyRate)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        Text("Aktueller Satz")
                            .font(.caption)
                            .bold()
                            .foregroundStyle(.secondary)

                        Text(hourlyRateSummary)
                            .font(.title2)
                            .bold()
                            .monospacedDigit()
                    }
                }
            }
        }
        .padding(sectionPadding)
        .background(
            RoundedRectangle(cornerRadius: sectionCornerRadius, style: .continuous)
                .fill(sectionCardGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: sectionCornerRadius, style: .continuous)
                .stroke(sectionCardStroke, lineWidth: 1)
        )
        .shadow(color: sectionCardShadow, radius: 14, x: 0, y: 8)
    }

    private var budgetSheet: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            budgetSheetContent(referenceDate: timeline.date)
        }
        .padding(sectionPadding)
#if os(macOS)
        .frame(minWidth: 620, minHeight: 440)
#else
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
#endif
    }

    @ViewBuilder
    private func budgetSheetContent(referenceDate: Date) -> some View {
        let snapshot = budgetSnapshot(referenceDate: referenceDate)

        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Projektbudget")
                    .font(.title2)
                    .bold()

                Spacer()

                Button(
                    isEditingBudgetInSheet ? "Fertig" : "Bearbeiten",
                    systemImage: "gearshape.fill"
                ) {
                    isEditingBudgetInSheet.toggle()
                }
                .buttonStyle(.bordered)

                Button("Schliessen", systemImage: "xmark") {
                    isEditingBudgetInSheet = false
                    isPresentingBudgetSheet = false
                }
                .buttonStyle(.bordered)
            }

            if let snapshot {
                HStack(alignment: .top, spacing: 20) {
                    BudgetProgressDonut(
                        snapshot: snapshot,
                        accentColor: project.projectActionColor
                    )
                    .frame(width: 170, height: 170)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(budgetValueText(snapshot.consumed, unit: snapshot.unit)) / \(budgetValueText(snapshot.target, unit: snapshot.unit))")
                            .font(.title2)
                            .bold()
                            .monospacedDigit()

                        Text(snapshot.progressText)
                            .font(.headline)
                            .foregroundStyle(snapshot.isOverBudget ? ClientProject.stopActionColor : project.projectActionColor)
                            .monospacedDigit()

                        Text(snapshot.statusText(unitFormatter: budgetValueText(_:unit:)))
                            .font(.subheadline)
                            .bold()
                            .foregroundStyle(snapshot.isOverBudget ? ClientProject.stopActionColor : .secondary)
                            .monospacedDigit()

                        Text(secondaryBudgetSummary(referenceDate: referenceDate, primaryUnit: snapshot.unit))
                            .font(.subheadline)
                            .bold()
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Spacer(minLength: 0)
                }
            } else if project.budgetUnit == .amount && !project.hasHourlyRate {
                Label(
                    "EUR-Budget kann erst mit hinterlegtem Stundensatz berechnet werden.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.subheadline)
                .bold()
                .foregroundStyle(.orange)
            } else {
                Text("Lege ein Stunden- oder Euro-Budget fest, damit der Projektverbrauch live verfolgt werden kann.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }

            if isEditingBudgetInSheet {
                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    if usesStackedRows {
                        Text("Budgettyp")
                            .font(.title3)
                            .bold()

                        Picker("Budgettyp", selection: $selectedBudgetUnit) {
                            Label("Stunden", systemImage: "clock")
                                .tag(ProjectBudgetUnit.hours)
                            Label("Euro", systemImage: "eurosign.circle")
                                .tag(ProjectBudgetUnit.amount)
                        }
                        .pickerStyle(.segmented)

                        Text(selectedBudgetUnit == .hours ? "Stundenbudget" : "Eurobudget")
                            .font(.title3)
                            .bold()

                        TextField(
                            selectedBudgetUnit == .hours ? "z. B. 20" : "z. B. 2500",
                            text: $budgetTargetText
                        )
                        .textFieldStyle(.roundedBorder)

                        Text(selectedBudgetUnit == .hours ? "Stunden" : "EUR")
                            .foregroundStyle(.secondary)

                        Button("Speichern", action: saveBudget)
                            .buttonStyle(.borderedProminent)
                            .tint(project.projectActionColor)
                            .disabled(hasInvalidBudgetTarget || selectedBudgetUnit == .amount && !project.hasHourlyRate)

                        if project.hasBudget {
                            Button("Entfernen", role: .destructive, action: clearBudget)
                                .buttonStyle(.bordered)
                        }
                    } else {
                        HStack(alignment: .center, spacing: 14) {
                            Text("Budgettyp")
                                .font(.title3)
                                .bold()
                                .frame(width: 130, alignment: .leading)

                            Picker("Budgettyp", selection: $selectedBudgetUnit) {
                                Label("Stunden", systemImage: "clock")
                                    .tag(ProjectBudgetUnit.hours)
                                Label("Euro", systemImage: "eurosign.circle")
                                    .tag(ProjectBudgetUnit.amount)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 290)
                        }

                        HStack(alignment: .center, spacing: 14) {
                            Text(selectedBudgetUnit == .hours ? "Stundenbudget" : "Eurobudget")
                                .font(.title3)
                                .bold()
                                .frame(width: 130, alignment: .leading)

                            TextField(
                                selectedBudgetUnit == .hours ? "z. B. 20" : "z. B. 2500",
                                text: $budgetTargetText
                            )
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 220)

                            Text(selectedBudgetUnit == .hours ? "Stunden" : "EUR")
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 12) {
                            Spacer(minLength: 144)

                            Button("Speichern", action: saveBudget)
                                .buttonStyle(.borderedProminent)
                                .tint(project.projectActionColor)
                                .disabled(hasInvalidBudgetTarget || selectedBudgetUnit == .amount && !project.hasHourlyRate)

                            if project.hasBudget {
                                Button("Entfernen", role: .destructive, action: clearBudget)
                                    .buttonStyle(.bordered)
                            }

                            Spacer(minLength: 0)
                        }
                    }
                }

                Text(budgetHintText)
                    .font(.caption)
                    .foregroundStyle(hasInvalidBudgetTarget ? .red : .secondary)
            } else {
                Text("Zum Aendern auf das Zahnrad klicken.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(sectionPadding)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.10 : 0.42),
                            Color.clear,
                            Color.black.opacity(colorScheme == .dark ? 0.12 : 0.04),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .allowsHitTesting(false)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.08),
                    lineWidth: 1
                )
                .allowsHitTesting(false)
        )
    }

    private var projectExportSheet: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Projekt exportieren")
                .font(.title)
                .bold()

            Text("\(project.displayClientName) - \(project.displayName)")
                .font(.headline)
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                Text("Format")
                    .font(.headline)
                Picker("Format", selection: $exportFormat) {
                    ForEach(ProjectExportFormat.allCases) { format in
                        Text(format.title).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: usesStackedRows ? .infinity : 240)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Inhalt")
                    .font(.headline)

                Picker("Inhalt", selection: $exportContentMode) {
                    ForEach(availableExportModes) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: usesStackedRows ? .infinity : 360)

                if !project.hasHourlyRate {
                    Label(
                        "Kostenexport ist erst moeglich, wenn ein Stundensatz hinterlegt ist.",
                        systemImage: "info.circle"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack {
                Spacer()

                Button("Abbrechen", role: .cancel) {
                    isPresentingExportSheet = false
                }

#if os(macOS)
                Button("Export starten", action: exportProjectData)
                    .buttonStyle(.borderedProminent)
                    .tint(project.projectActionColor)
#else
                Button(hasPreparedExportForCurrentSelection ? "Neu erstellen" : "Export vorbereiten", action: exportProjectData)
                    .buttonStyle(.bordered)

                if hasPreparedExportForCurrentSelection,
                   let preparedExportURL {
                    ShareLink(item: preparedExportURL) {
                        Label("Export teilen", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(project.projectActionColor)
                }
#endif
            }
        }
        .padding(sectionPadding)
#if os(macOS)
        .frame(width: 520)
#else
        .frame(maxWidth: .infinity, alignment: .leading)
#endif
    }

    private var manualEntryButton: some View {
        Button(action: onAddManualEntry) {
            Label("Eintrag nachtragen", systemImage: "calendar.badge.plus")
                .frame(minWidth: isCompactWidth ? nil : 220)
                .frame(maxWidth: isCompactWidth ? .infinity : nil)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    @ViewBuilder
    private func summaryRow(referenceDate: Date) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: summaryGridMinimum), spacing: 14),
            ],
            spacing: 14
        ) {
            SummaryCard(
                title: "Gesamtzeit",
                value: TimeFormatting.compactDuration(totalDuration(referenceDate: referenceDate)),
                subtitle: "\(project.sessions.count) Sitzungen"
            )

            SummaryCard(
                title: "Gesamtwert",
                value: totalValueText(referenceDate: referenceDate),
                subtitle: project.hasHourlyRate ? "Aus Zeit und Stundensatz" : "Stundensatz fehlt"
            )

            SummaryCard(
                title: "Heute",
                value: TimeFormatting.compactDuration(todayDuration(referenceDate: referenceDate)),
                subtitle: "Seit 00:00 Uhr"
            )

            SummaryCard(
                title: "Stundensatz",
                value: hourlyRateSummary,
                subtitle: project.hasHourlyRate ? "Pro Stunde" : "Noch nicht hinterlegt",
                accessorySystemImage: "gearshape.fill",
                accessoryAction: toggleHourlyRateEditing
            )

            SummaryCard(
                title: "Budget",
                value: budgetSummaryValue(referenceDate: referenceDate),
                subtitle: budgetSummarySubtitle(referenceDate: referenceDate),
                accessorySystemImage: "info.circle",
                accessoryAction: presentBudgetDetails
            )
        }
    }

    private var tasksCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text("Aufgaben")
                        .font(.title2)
                        .bold()

                    Spacer()

                    Text("\(project.tasks.count) gesamt")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Aufgaben")
                        .font(.title2)
                        .bold()

                    Text("\(project.tasks.count) gesamt")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if !project.isArchived {
                if usesStackedRows {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Neue Aufgabe", text: $newTaskTitle)
                            .textFieldStyle(.roundedBorder)

                        Button("Aufgabe hinzufuegen", action: addTask)
                            .buttonStyle(.borderedProminent)
                            .tint(project.projectActionColor)
                            .disabled(trimmedNewTaskTitle.isEmpty)
                    }
                } else {
                    HStack(alignment: .center, spacing: 12) {
                        TextField("Neue Aufgabe", text: $newTaskTitle)
                            .textFieldStyle(.roundedBorder)

                        Button("Aufgabe hinzufuegen", action: addTask)
                            .buttonStyle(.borderedProminent)
                            .tint(project.projectActionColor)
                            .disabled(trimmedNewTaskTitle.isEmpty)
                    }
                }

                if let selectedTaskForStart {
                    Label(
                        "Zeiterfassung startet mit: \(selectedTaskForStart.displayTitle)",
                        systemImage: "scope"
                    )
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(project.projectAccentColor)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            if project.sortedTasks.isEmpty {
                Text(project.isArchived ? "Dieses Projekt hat keine Aufgaben." : "Lege Aufgaben an, damit du Zeiten direkt auf Arbeitspakete buchen kannst.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    LazyVStack(spacing: 12) {
                        ForEach(project.sortedTasks) { task in
                            TaskSummaryRow(
                                title: task.displayTitle,
                                subtitle: "\(taskSessionCount(for: task)) Eintraege",
                                durationText: TimeFormatting.compactDuration(taskDuration(for: task, referenceDate: timeline.date)),
                                valueText: taskValueText(for: task, referenceDate: timeline.date),
                                isActive: activeSession?.task?.id == task.id,
                                isSelectedForStart: selectedTaskForStart?.id == task.id,
                                isProjectRunningWithoutTask: isProjectRunningWithoutTask,
                                accentColor: project.projectActionColor,
                                isArchived: project.isArchived,
                                onSelectForStart: {
                                    selectTaskForStart(task)
                                },
                                onStart: {
                                    onStartTask(task)
                                },
                                onStop: onStop
                            )
                        }
                    }
                }
            }
        }
        .padding(sectionPadding)
        .background(
            RoundedRectangle(cornerRadius: sectionCornerRadius, style: .continuous)
                .fill(sectionCardGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: sectionCornerRadius, style: .continuous)
                .stroke(sectionCardStroke, lineWidth: 1)
        )
        .shadow(color: sectionCardShadow, radius: 14, x: 0, y: 8)
    }

    private var sessionsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text("Letzte Eintraege")
                        .font(.title2)
                        .bold()

                    Spacer()

                    Button(action: onAddManualEntry) {
                        Label("Nachtragen", systemImage: "plus.circle")
                    }

                    Text("\(project.sessions.count) gesamt")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Letzte Eintraege")
                            .font(.title2)
                            .bold()

                        Spacer()

                        Text("\(project.sessions.count) gesamt")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Button(action: onAddManualEntry) {
                        Label("Nachtragen", systemImage: "plus.circle")
                    }
                }
            }

            if project.sortedSessions.isEmpty {
                Text("Noch keine Zeit erfasst. Starte oben den ersten Timer fuer dieses Projekt.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 18)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(project.sortedSessions) { session in
                        SessionRow(
                            session: session,
                            hourlyRate: project.hourlyRate,
                            availableTasks: project.sortedTasks,
                            onAssignToTask: { task in
                                assignSession(session, to: task)
                            },
                            onCreateTaskAndAssign: {
                                sessionPendingTaskCreation = session
                            },
                            onEdit: session.isActive ? nil : {
                                onEditSession(session)
                            },
                            onDelete: session.isActive ? nil : {
                                sessionPendingDeletion = session
                            }
                        )
                    }
                }
            }
        }
        .padding(sectionPadding)
        .background(
            RoundedRectangle(cornerRadius: sectionCornerRadius, style: .continuous)
                .fill(sectionCardGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: sectionCornerRadius, style: .continuous)
                .stroke(sectionCardStroke, lineWidth: 1)
        )
        .shadow(color: sectionCardShadow, radius: 14, x: 0, y: 8)
    }

    private func totalDuration(referenceDate: Date) -> TimeInterval {
        project.sessions.reduce(into: 0) { partialResult, session in
            partialResult += session.duration(referenceDate: referenceDate)
        }
    }

    private func todayDuration(referenceDate: Date) -> TimeInterval {
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

    private var actionButtonTitle: String {
        if project.isArchived {
            return "Projekt reaktivieren"
        }

        if isActiveProject {
            return "Zeiterfassung stoppen"
        }

        return project.tasks.isEmpty ? "Zeiterfassung starten" : "Ausgewaehlte Aufgabe starten"
    }

    private var actionButtonSystemImage: String {
        if project.isArchived {
            return "arrow.uturn.backward.circle.fill"
        }

        return isActiveProject ? "stop.fill" : "play.fill"
    }

    private var actionButtonTint: Color {
        if project.isArchived {
            return ClientProject.primaryActionColor
        }

        return isActiveProject ? ClientProject.stopActionColor : project.projectActionColor
    }

    private var headerPrimaryStyle: Color {
        colorScheme == .dark ? Color.white.opacity(0.96) : Color.black.opacity(0.9)
    }

    private var headerSecondaryStyle: Color {
        colorScheme == .dark ? Color.white.opacity(0.78) : Color.black.opacity(0.62)
    }

    private var headerInnerSurfaceStyle: Color {
        colorScheme == .dark ? Color.black.opacity(0.28) : Color.white.opacity(0.72)
    }

    private var headerStrokeStyle: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.06)
    }

    private var headerShadowStyle: Color {
        colorScheme == .dark ? Color.black.opacity(0.32) : Color.black.opacity(0.05)
    }

    private var headerCardGradient: LinearGradient {
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

    private var pageBackgroundGradient: LinearGradient {
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

    private var sectionCardGradient: LinearGradient {
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

    private var sectionCardStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.10)
    }

    private var sectionCardShadow: Color {
        colorScheme == .dark ? Color.black.opacity(0.14) : Color.black.opacity(0.08)
    }

    private var trimmedNewTaskTitle: String {
        newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedTaskForStart: ProjectTask? {
        if let selectedTaskID,
           let selectedTask = project.tasks.first(where: { $0.id == selectedTaskID }) {
            return selectedTask
        }

        return project.sortedTasks.first
    }

    private func syncSelectedTaskForStart() {
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

    private func selectTaskForStart(_ task: ProjectTask) {
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

    private func taskSessionCount(for task: ProjectTask) -> Int {
        project.sessions.filter { $0.task?.id == task.id }.count
    }

    private func taskDuration(
        for task: ProjectTask,
        referenceDate: Date
    ) -> TimeInterval {
        duration(for: task.id, referenceDate: referenceDate)
    }

    private func duration(
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

    private func taskValueText(
        for task: ProjectTask,
        referenceDate: Date
    ) -> String {
        valueText(forDuration: taskDuration(for: task, referenceDate: referenceDate))
    }

    private func valueText(forDuration duration: TimeInterval) -> String {
        guard let billedAmount = project.billedAmount(for: duration) else {
            return "Offen"
        }

        return TimeFormatting.euroAmount(billedAmount)
    }

    private func addTask() {
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

    private func assignSession(
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

    private func createTaskAndAssignSession(
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

    private var parsedHourlyRate: Double? {
        TimeFormatting.parseDecimalInput(hourlyRateText)
    }

    private var hasInvalidHourlyRate: Bool {
        let trimmed = hourlyRateText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return false
        }

        guard let parsedHourlyRate else {
            return true
        }

        return parsedHourlyRate < 0
    }

    private var hourlyRateHint: String {
        if hasInvalidHourlyRate {
            return "Bitte gib einen gueltigen nicht-negativen Betrag ein."
        }

        return "Leer lassen, wenn das Projekt noch keinen Stundensatz hat."
    }

    private var hourlyRateSummary: String {
        guard project.hasHourlyRate else {
            return "Offen"
        }

        return TimeFormatting.euroAmount(project.effectiveHourlyRate)
    }

    private var parsedBudgetTarget: Double? {
        TimeFormatting.parseDecimalInput(budgetTargetText)
    }

    private var hasInvalidBudgetTarget: Bool {
        let trimmed = budgetTargetText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return false
        }

        guard let parsedBudgetTarget else {
            return true
        }

        return parsedBudgetTarget <= 0
    }

    private var budgetHintText: String {
        if hasInvalidBudgetTarget {
            return "Bitte gib einen gueltigen positiven Wert ein."
        }

        if selectedBudgetUnit == .amount && !project.hasHourlyRate {
            return "Fuer ein EUR-Budget bitte zuerst einen Stundensatz hinterlegen."
        }

        return "Leer lassen, wenn fuer dieses Projekt aktuell kein Budget gelten soll."
    }

    private func budgetSummaryValue(referenceDate: Date) -> String {
        guard project.hasBudget else {
            return "Offen"
        }

        return budgetHoursSummary(referenceDate: referenceDate)
    }

    private func budgetSummarySubtitle(referenceDate: Date) -> String {
        guard project.hasBudget else {
            return "Wert: Offen"
        }

        return "Wert: \(budgetAmountSummary(referenceDate: referenceDate))"
    }

    private func budgetHoursSummary(referenceDate: Date) -> String {
        let duration = totalDuration(referenceDate: referenceDate)
        let consumedHours = project.budgetValue(for: duration, in: .hours) ?? 0
        let consumedText = budgetValueText(consumedHours, unit: .hours)

        guard let targetHours = project.budgetTargetValue(in: .hours) else {
            return consumedText
        }

        return "\(consumedText) / \(budgetValueText(targetHours, unit: .hours))"
    }

    private func budgetAmountSummary(referenceDate: Date) -> String {
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

    private func secondaryBudgetSummary(
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

    private var availableExportModes: [ProjectExportContentMode] {
        if project.hasHourlyRate {
            return ProjectExportContentMode.allCases
        }

        return [.hoursOnly]
    }

    private func budgetSnapshot(referenceDate: Date) -> ProjectBudgetSnapshot? {
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

    private func budgetValueText(
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

    private func convertBudgetEditorValue(
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

    private var shouldShowBillingCard: Bool {
        !project.hasHourlyRate || isEditingHourlyRate
    }

    private var runningSessionWithoutTask: WorkSession? {
        guard isProjectRunningWithoutTask else {
            return nil
        }

        return activeSession
    }

    private var billingAlertIsPresented: Binding<Bool> {
        Binding(
            get: { billingErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    billingErrorMessage = nil
                }
            }
        )
    }

    private var sessionDeletionIsPresented: Binding<Bool> {
        Binding(
            get: { sessionPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    sessionPendingDeletion = nil
                }
            }
        )
    }

    private func totalValueText(referenceDate: Date) -> String {
        guard let billedAmount = project.billedAmount(for: totalDuration(referenceDate: referenceDate)) else {
            return "Offen"
        }

        return TimeFormatting.euroAmount(billedAmount)
    }

    private func syncHourlyRateText() {
        hourlyRateText = TimeFormatting.decimalInput(project.hourlyRate)
    }

    private func toggleHourlyRateEditing() {
        if project.hasHourlyRate {
            isEditingHourlyRate.toggle()
        } else {
            isEditingHourlyRate = true
        }

        syncHourlyRateText()
    }

    private func saveHourlyRate() {
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

    private func syncBudgetEditor() {
        isSyncingBudgetEditor = true
        defer { isSyncingBudgetEditor = false }

        selectedBudgetUnit = project.budgetUnit ?? .hours
        budgetTargetText = TimeFormatting.decimalInput(project.effectiveBudgetTarget)
    }

    private func syncExportConfiguration() {
        if !project.hasHourlyRate {
            exportContentMode = .hoursOnly
        }

        invalidatePreparedExport()
    }

    private var currentExportSelection: ProjectExportSelection {
        ProjectExportSelection.current(
            format: exportFormat,
            selectedMode: exportContentMode,
            hasHourlyRate: project.hasHourlyRate
        )
    }

    private var hasPreparedExportForCurrentSelection: Bool {
        guard preparedExportURL != nil else {
            return false
        }

        return preparedExportSelection == currentExportSelection
    }

    private func invalidatePreparedExport() {
        preparedExportURL = nil
        preparedExportSelection = nil
    }

    private func presentBudgetDetails() {
        syncBudgetEditor()
        isEditingBudgetInSheet = false
        isPresentingBudgetSheet = true
    }

    private func presentProjectExportSheet() {
        syncExportConfiguration()
        isPresentingExportSheet = true
    }

    private func exportProjectData() {
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
    private func presentExportSavePanel(
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

    private func defaultExportFileName(
        for format: ProjectExportFormat
    ) -> String {
        ProjectExportFileNaming.defaultFileName(
            projectName: project.displayName,
            format: format
        )
    }

    private func makePreparedExportURL(
        for format: ProjectExportFormat
    ) -> URL {
        URL.temporaryDirectory.appending(path: defaultExportFileName(for: format))
    }

#if os(macOS)
    private func utType(for format: ProjectExportFormat) -> UTType {
        switch format {
        case .csv:
            return .commaSeparatedText
        case .pdf:
            return .pdf
        }
    }
#endif

    private func saveBudget() {
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

    private func clearBudget() {
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

    private var projectAccentColorBinding: Binding<Color> {
        Binding(
            get: { project.projectAccentColor },
            set: { newColor in
                saveProjectAccentColor(newColor)
            }
        )
    }

    private func saveProjectAccentColor(_ color: Color) {
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

    private func resetProjectAccentColor() {
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

private struct ProjectBudgetSnapshot {
    let unit: ProjectBudgetUnit
    let target: Double
    let consumed: Double

    var remaining: Double {
        target - consumed
    }

    var progress: Double {
        guard target > 0 else {
            return 0
        }

        return consumed / target
    }

    var isOverBudget: Bool {
        remaining < 0
    }

    var progressText: String {
        progress.formatted(
            .percent
                .precision(.fractionLength(0))
        )
    }

    func statusText(unitFormatter: (Double, ProjectBudgetUnit) -> String) -> String {
        if remaining > 0 {
            return "Restbudget: \(unitFormatter(remaining, unit))"
        }

        if remaining < 0 {
            return "Ueberzogen um \(unitFormatter(abs(remaining), unit))"
        }

        return "Budget exakt erreicht"
    }
}

private struct BudgetProgressDonut: View {
    let snapshot: ProjectBudgetSnapshot
    let accentColor: Color

    private var chartSegments: [BudgetProgressSegment] {
        let consumedInTarget = min(max(snapshot.consumed, 0), max(snapshot.target, 0))
        let remaining = max(snapshot.target - consumedInTarget, 0)
        let overBudget = max(snapshot.consumed - snapshot.target, 0)

        var segments: [BudgetProgressSegment] = []

        if consumedInTarget > 0 {
            segments.append(
                BudgetProgressSegment(
                    label: "Verbraucht",
                    value: consumedInTarget,
                    color: accentColor
                )
            )
        }

        if remaining > 0 {
            segments.append(
                BudgetProgressSegment(
                    label: "Rest",
                    value: remaining,
                    color: .secondary.opacity(0.28)
                )
            )
        }

        if overBudget > 0 {
            segments.append(
                BudgetProgressSegment(
                    label: "Ueber Budget",
                    value: overBudget,
                    color: ClientProject.stopActionColor
                )
            )
        }

        if segments.isEmpty {
            return [
                BudgetProgressSegment(
                    label: "Leer",
                    value: 1,
                    color: .secondary.opacity(0.18)
                )
            ]
        }

        return segments
    }

    var body: some View {
        Chart(chartSegments) { segment in
            SectorMark(
                angle: .value("Anteil", segment.value),
                innerRadius: .ratio(0.64),
                angularInset: 1
            )
            .foregroundStyle(segment.color)
        }
        .chartLegend(.hidden)
    }
}

private struct BudgetProgressSegment: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let color: Color
}

private struct SummaryCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let title: String
    let value: String
    let subtitle: String
    var accessorySystemImage: String? = nil
    var accessoryAction: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(summarySecondaryStyle)

                Spacer(minLength: 0)

                if let accessoryAction {
                    Button(action: accessoryAction) {
                        Image(systemName: accessorySystemImage ?? "gearshape.fill")
                            .font(.footnote)
                            .bold()
                            .foregroundStyle(summarySecondaryStyle)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(value)
                .font(horizontalSizeClass == .compact ? .title2 : .title)
                .bold()
                .monospacedDigit()
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(summarySecondaryStyle)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(horizontalSizeClass == .compact ? 16 : 22)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(summaryCardGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(summaryCardStroke, lineWidth: 1)
        )
        .shadow(color: summaryCardShadow, radius: 10, x: 0, y: 6)
    }

    private var summarySecondaryStyle: Color {
        colorScheme == .dark ? Color.white.opacity(0.66) : Color.black.opacity(0.60)
    }

    private var summaryCardGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [Color.white.opacity(0.07), Color.black.opacity(0.24)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [Color.white.opacity(0.98), Color(red: 0.96, green: 0.97, blue: 0.99)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var summaryCardStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.10)
    }

    private var summaryCardShadow: Color {
        colorScheme == .dark ? Color.black.opacity(0.12) : Color.black.opacity(0.07)
    }
}

private struct TaskSummaryRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let title: String
    let subtitle: String
    let durationText: String
    let valueText: String
    let isActive: Bool
    let isSelectedForStart: Bool
    let isProjectRunningWithoutTask: Bool
    let accentColor: Color
    let isArchived: Bool
    let onSelectForStart: () -> Void
    let onStart: () -> Void
    let onStop: () -> Void

    private var shouldShowStop: Bool {
        isActive || (isSelectedForStart && isProjectRunningWithoutTask)
    }

    private var usesStackedLayout: Bool {
        ProjectDetailLayoutMetrics.usesStackedRow(
            dynamicTypeSize: dynamicTypeSize,
            horizontalSizeClass: horizontalSizeClass
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onSelectForStart) {
                if usesStackedLayout {
                    VStack(alignment: .leading, spacing: 10) {
                        taskTitleBlock

                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(rowSecondaryStyle)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: 0)

                            taskMetricBlock(alignment: .trailing)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
                } else {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            taskTitleBlock

                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(rowSecondaryStyle)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        taskMetricBlock(alignment: .trailing)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
                }
            }
            .buttonStyle(.plain)
            .disabled(isArchived)

            if !isArchived {
                Button(action: {
                    if shouldShowStop {
                        onStop()
                    } else {
                        onStart()
                    }
                }) {
                    Label(
                        shouldShowStop ? "Stoppen" : "Starten",
                        systemImage: shouldShowStop ? "stop.fill" : "play.fill"
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.borderedProminent)
                .tint(shouldShowStop ? ClientProject.stopActionColor : accentColor)
            }
        }
        .padding(usesStackedLayout ? 14 : 18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(rowGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    isSelectedForStart ? accentColor.opacity(0.55) : rowStroke,
                    lineWidth: isSelectedForStart ? 1.5 : 1
                )
        )
        .shadow(color: rowShadow, radius: 6, x: 0, y: 3)
    }

    private var taskTitleBlock: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title)
                .font(.headline)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            if isSelectedForStart {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(accentColor)
            }
        }
    }

    private func taskMetricBlock(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(durationText)
                .font(.title3)
                .bold()
                .monospacedDigit()
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            Text(valueText)
                .font(.caption)
                .bold()
                .foregroundStyle(rowSecondaryStyle)
                .monospacedDigit()
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var rowSecondaryStyle: Color {
        colorScheme == .dark ? Color.white.opacity(0.66) : Color.black.opacity(0.60)
    }

    private var rowGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [Color.white.opacity(0.06), Color.black.opacity(0.20)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [Color.white, Color(red: 0.96, green: 0.97, blue: 0.99)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var rowStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.09)
    }

    private var rowShadow: Color {
        colorScheme == .dark ? Color.black.opacity(0.10) : Color.black.opacity(0.05)
    }
}

private struct SessionRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let session: WorkSession
    let hourlyRate: Double?
    let availableTasks: [ProjectTask]
    let onAssignToTask: ((ProjectTask?) -> Void)?
    let onCreateTaskAndAssign: (() -> Void)?
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?

    private var hasActions: Bool {
        onAssignToTask != nil || onCreateTaskAndAssign != nil || onEdit != nil || onDelete != nil
    }

    private var usesStackedLayout: Bool {
        ProjectDetailLayoutMetrics.usesStackedRow(
            dynamicTypeSize: dynamicTypeSize,
            horizontalSizeClass: horizontalSizeClass
        )
    }

    private var rowSpacing: CGFloat {
        ProjectDetailLayoutMetrics.sessionRowSpacing(
            dynamicTypeSize: dynamicTypeSize,
            horizontalSizeClass: horizontalSizeClass
        )
    }

    private var rowPadding: CGFloat {
        ProjectDetailLayoutMetrics.sessionRowPadding(
            dynamicTypeSize: dynamicTypeSize,
            horizontalSizeClass: horizontalSizeClass
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            if usesStackedLayout {
                HStack(alignment: .top, spacing: 10) {
                    compactSessionInfoBlock

                    Spacer(minLength: 8)

                    actionMenu
                }

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(timeRangeText)
                        .font(.subheadline)
                        .foregroundStyle(rowSecondaryStyle)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)

                    statusBadge
                }

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    SessionDurationText(session: session)

                    Spacer(minLength: 0)

                    billedAmountView
                }
            } else {
                HStack(spacing: 18) {
                    sessionInfoBlock

                    Spacer()

                    statusBadge

                    actionMenu

                    VStack(alignment: .trailing, spacing: 6) {
                        SessionDurationText(session: session)
                        billedAmountView
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(rowPadding)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(rowGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(rowStroke, lineWidth: 1)
        )
        .shadow(color: rowShadow, radius: 6, x: 0, y: 3)
    }

    private var compactSessionInfoBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(TimeFormatting.shortDate(session.startedAt))
                .font(.headline)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            Text(session.displayTaskTitle)
                .font(.subheadline)
                .bold()
                .foregroundStyle(rowSecondaryStyle)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var sessionInfoBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(TimeFormatting.shortDate(session.startedAt))
                .font(.headline)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            Text(session.displayTaskTitle)
                .font(.subheadline)
                .bold()
                .foregroundStyle(rowSecondaryStyle)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            Text(timeRangeText)
                .font(.subheadline)
                .foregroundStyle(rowSecondaryStyle)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var timeRangeText: String {
        if let endedAt = session.endedAt {
            return "\(TimeFormatting.shortTime(session.startedAt)) - \(TimeFormatting.shortTime(endedAt))"
        }

        return "Seit \(TimeFormatting.shortTime(session.startedAt))"
    }

    @ViewBuilder
    private var actionMenu: some View {
        if hasActions {
            Menu {
                if let onAssignToTask, !availableTasks.isEmpty {
                    Menu("Aufgabe zuordnen") {
                        ForEach(availableTasks) { task in
                            Button(task.displayTitle) {
                                onAssignToTask(task)
                            }
                        }

                        if session.task != nil {
                            Divider()

                            Button("Zuordnung entfernen") {
                                onAssignToTask(nil)
                            }
                        }
                    }
                }

                if let onCreateTaskAndAssign {
                    Button(action: onCreateTaskAndAssign) {
                        Label("Neue Aufgabe erstellen + zuordnen", systemImage: "plus")
                    }
                }

                if (onAssignToTask != nil && !availableTasks.isEmpty) || onCreateTaskAndAssign != nil {
                    Divider()
                }

                if let onEdit {
                    Button(action: onEdit) {
                        Label("Bearbeiten", systemImage: "square.and.pencil")
                    }
                }

                if let onDelete {
                    Button(role: .destructive, action: onDelete) {
                        Label("Loeschen", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.headline)
                    .foregroundStyle(rowSecondaryStyle)
            }
#if os(macOS)
            .menuStyle(.borderlessButton)
#endif
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        Text(session.isActive ? "Aktiv" : "Beendet")
            .font(.caption)
            .bold()
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(session.isActive ? activeBadgeColor.opacity(0.16) : Color.gray.opacity(0.16))
            )
            .foregroundStyle(session.isActive ? activeBadgeColor : .secondary)
    }

    @ViewBuilder
    private var billedAmountView: some View {
        if let hourlyRate {
            if session.isActive {
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    amountLabel(
                        amount: max(session.duration(referenceDate: timeline.date) / 3600, 0) * max(hourlyRate, 0)
                    )
                }
            } else {
                amountLabel(
                    amount: max(session.recordedDuration / 3600, 0) * max(hourlyRate, 0)
                )
            }
        }
    }

    private func amountLabel(amount: Double) -> some View {
        Text(TimeFormatting.euroAmount(amount))
            .font(.caption)
            .bold()
            .foregroundStyle(rowSecondaryStyle)
            .monospacedDigit()
    }

    private var activeBadgeColor: Color {
        session.project?.projectAccentColor ?? .teal
    }

    private var rowSecondaryStyle: Color {
        colorScheme == .dark ? Color.white.opacity(0.66) : Color.black.opacity(0.60)
    }

    private var rowGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [Color.white.opacity(0.06), Color.black.opacity(0.20)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [Color.white, Color(red: 0.96, green: 0.97, blue: 0.99)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var rowStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.09)
    }

    private var rowShadow: Color {
        colorScheme == .dark ? Color.black.opacity(0.10) : Color.black.opacity(0.05)
    }
}

private struct NewTaskAssignmentSheet: View {
    @Environment(\.dismiss) private var dismiss

    let project: ClientProject
    let session: WorkSession
    let onSave: (String) -> Bool

    @State private var taskTitle = ""
    @State private var validationMessage: String?

    private var trimmedTaskTitle: String {
        taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Neue Aufgabe fuer Zeiteintrag")
                .font(.title2)
                .bold()

            Text("\(project.displayClientName) - \(project.displayName)")
                .foregroundStyle(.secondary)

            Text("Eintrag: \(TimeFormatting.shortDate(session.startedAt)) \(TimeFormatting.shortTime(session.startedAt))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("Aufgabentitel", text: $taskTitle)
                .textFieldStyle(.roundedBorder)

            if let validationMessage {
                Text(validationMessage)
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()

                Button("Abbrechen", role: .cancel) {
                    dismiss()
                }

                Button("Erstellen und zuordnen") {
                    validationMessage = nil

                    guard !trimmedTaskTitle.isEmpty else {
                        validationMessage = "Bitte gib einen Aufgabentitel ein."
                        return
                    }

                    if onSave(trimmedTaskTitle) {
                        dismiss()
                    } else {
                        validationMessage = "Die Aufgabe konnte nicht erstellt werden."
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(project.projectActionColor)
                .disabled(trimmedTaskTitle.isEmpty)
            }
        }
        .padding(24)
#if os(macOS)
        .frame(width: 460)
#else
        .frame(maxWidth: .infinity, alignment: .leading)
#endif
    }
}

private struct SessionDurationText: View {
    let session: WorkSession

    var body: some View {
        Group {
            if session.isActive {
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    durationLabel(interval: session.duration(referenceDate: timeline.date))
                }
            } else {
                durationLabel(interval: session.recordedDuration)
            }
        }
    }

    private func durationLabel(interval: TimeInterval) -> some View {
        Text(TimeFormatting.digitalDuration(interval))
            .font(.headline)
            .bold()
            .monospacedDigit()
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
