import SwiftData
import SwiftUI

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
    @Environment(\.modelContext) var modelContext
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

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

    @State var hourlyRateText = ""
    @State var budgetTargetText = ""
    @State var newTaskTitle = ""
    @State var selectedBudgetUnit: ProjectBudgetUnit = .hours
    @State var isEditingHourlyRate = false
    @State var isPresentingBudgetSheet = false
    @State var isEditingBudgetInSheet = false
    @State var isPresentingExportSheet = false
    @State var exportFormat: ProjectExportFormat = .csv
    @State var exportContentMode: ProjectExportContentMode = .hoursAndCosts
    @State var preparedExportURL: URL?
    @State var preparedExportSelection: ProjectExportSelection?
    @State var isSyncingBudgetEditor = false
    @State var billingErrorMessage: String?
    @State var isConfirmingProjectArchive = false
    @State var isConfirmingProjectDeletion = false
    @State var sessionPendingTaskCreation: WorkSession?
    @State var sessionPendingDeletion: WorkSession?
    @State var selectedTaskID: UUID?

    var isActiveProject: Bool {
        activeSession?.project?.id == project.id
    }

    var isProjectRunningWithoutTask: Bool {
        guard activeSession?.project?.id == project.id else {
            return false
        }

        return activeSession?.task == nil
    }

    var isCompactWidth: Bool {
        horizontalSizeClass == .compact
    }

    var contentPadding: CGFloat {
        ProjectDetailLayoutMetrics.contentPadding(horizontalSizeClass: horizontalSizeClass)
    }

    var sectionPadding: CGFloat {
        ProjectDetailLayoutMetrics.sectionPadding(horizontalSizeClass: horizontalSizeClass)
    }

    var summaryGridMinimum: CGFloat {
        ProjectDetailLayoutMetrics.summaryGridMinimum(horizontalSizeClass: horizontalSizeClass)
    }

    var usesStackedRows: Bool {
        ProjectDetailLayoutMetrics.usesStackedRow(
            dynamicTypeSize: dynamicTypeSize,
            horizontalSizeClass: horizontalSizeClass
        )
    }

    var sectionCornerRadius: CGFloat {
        isCompactWidth ? 22 : 28
    }

    var headerCornerRadius: CGFloat {
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

    var headerCard: some View {
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

    var headerPrimaryInfo: some View {
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

    var actionButton: some View {
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

    var projectActionsButton: some View {
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

    var projectColorControls: some View {
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

    var billingCard: some View {
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

    var budgetSheet: some View {
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

    var projectExportSheet: some View {
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

    var manualEntryButton: some View {
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

    var tasksCard: some View {
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

    var sessionsCard: some View {
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


}
