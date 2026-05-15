import SwiftData
import SwiftUI
import UniformTypeIdentifiers
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Root

struct MacRedesignedRootView: View {
    @Environment(\.modelContext) private var modelContext
    let trackingStatus: TrackingStatusStore
    let dependencies: AppDependencies

    @Query(
        sort: [
            SortDescriptor(\ClientProject.clientName),
            SortDescriptor(\ClientProject.name),
        ]
    )
    private var projects: [ClientProject]

    @Query(
        filter: #Predicate<WorkSession> { $0.endedAt == nil },
        sort: [SortDescriptor(\WorkSession.startedAt, order: .forward)]
    )
    private var activeSessions: [WorkSession]

    @AppStorage("tt.projectColorVariant") private var variantRaw: String = ProjectColorVariant.chromed.rawValue
    @AppStorage("tt.macMode") private var macMode: String = "rec"

    @State private var selectedProjectID: UUID?
    @State private var search: String = ""
    @State private var presentingNewProject = false
    @State private var manualEntryProject: ClientProject?
    @State private var sessionToEdit: WorkSession?
    @State private var errorMessage: String?

    private var variant: ProjectColorVariant {
        ProjectColorVariant(rawValue: variantRaw) ?? .chromed
    }

    private var activeProjects: [ClientProject] {
        projects.filter { !$0.isArchived }
    }

    private var activeSession: WorkSession? { activeSessions.first }

    private var selectedProject: ClientProject? {
        if let id = selectedProjectID,
           let p = activeProjects.first(where: { $0.id == id }) {
            return p
        }
        return activeSession?.project ?? activeProjects.first
    }

    var body: some View {
        NavigationSplitView {
            MacSidebarPane(
                projects: activeProjects,
                activeProjectId: activeSession?.project?.id,
                search: $search,
                selectedId: $selectedProjectID,
                onAddProject: { presentingNewProject = true }
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 300)
        } detail: {
            VStack(spacing: 0) {
                Divider().background(TTColors.separator)
                content
            }
            .background(TTColors.bg.ignoresSafeArea())
        }
        .navigationSplitViewStyle(.balanced)
        .environment(\.projectColorVariant, variant)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("", selection: $macMode) {
                    Label("Aufnehmen", systemImage: "clock").tag("rec")
                    Label("Auswertung", systemImage: "chart.bar.xaxis").tag("rep")
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Darstellung", selection: $variantRaw) {
                        Text("Wash").tag(ProjectColorVariant.tinted.rawValue)
                        Text("Bar").tag(ProjectColorVariant.chromed.rawValue)
                    }
                } label: {
                    Image(systemName: "paintpalette")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if let project = selectedProject, activeSession?.project?.id != project.id {
                        startTracking(project: project, task: nil)
                    } else if activeSession != nil {
                        stopActiveTracking()
                    }
                } label: {
                    if activeSession != nil {
                        Label("Stop", systemImage: "stop.fill")
                    } else {
                        Label("Timer starten", systemImage: "play.fill")
                    }
                }
                .disabled(selectedProject == nil)
            }
        }
        .sheet(isPresented: $presentingNewProject) {
            NewProjectSheet(initialClientName: "") { project in
                modelContext.insert(project)
                do {
                    try modelContext.save()
                    selectedProjectID = project.id
                    return true
                } catch {
                    modelContext.delete(project)
                    errorMessage = "Das Projekt konnte nicht gespeichert werden."
                    return false
                }
            }
        }
        .sheet(item: $manualEntryProject) { project in
            ManualSessionSheet(project: project) { start, end, task in
                addManualSession(for: project, task: task, startedAt: start, endedAt: end)
            }
        }
        .sheet(item: $sessionToEdit) { session in
            if let project = session.project {
                ManualSessionSheet(project: project, sessionToEdit: session) { start, end, task in
                    updateManualSession(session, task: task, startedAt: start, endedAt: end)
                }
            }
        }
        .alert("Aktion fehlgeschlagen", isPresented: errorBinding) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    @ViewBuilder
    private var content: some View {
        if let project = selectedProject {
            if macMode == "rep" {
                MacAuswertungPane(projects: projects)
            } else {
                MacAufnehmenPane(
                    project: project,
                    activeSession: activeSession,
                    onStartTask: { task in startTracking(project: project, task: task) },
                    onStartProject: { startTracking(project: project, task: nil) },
                    onStop: stopActiveTracking,
                    onAddManualEntry: { manualEntryProject = project },
                    onEditEntry: { session in sessionToEdit = session },
                    onAddTask: { title in
                        let task = ProjectTask(title: title, project: project)
                        modelContext.insert(task)
                        try? modelContext.save()
                    }
                )
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "tray").font(.system(size: 36)).foregroundStyle(TTColors.text3)
                Text("Noch keine Projekte")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(TTColors.text)
                Button("Projekt anlegen") { presentingNewProject = true }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Actions

    private func startTracking(project: ClientProject, task: ProjectTask?) {
        do {
            try dependencies.workspaceTrackingUseCases.startTracking(
                project: project, task: task, in: modelContext, at: .now
            )
            trackingStatus.refresh()
        } catch let trackingError as TrackingManagerError {
            errorMessage = trackingError.errorDescription
        } catch {
            errorMessage = "Die Zeiterfassung konnte nicht gestartet werden."
        }
    }

    private func stopActiveTracking() {
        do {
            try dependencies.workspaceTrackingUseCases.stopActiveTracking(in: modelContext, at: .now)
            trackingStatus.refresh()
        } catch {
            errorMessage = "Die laufende Zeiterfassung konnte nicht beendet werden."
        }
    }

    private func addManualSession(for project: ClientProject, task: ProjectTask?, startedAt: Date, endedAt: Date) -> Bool {
        do {
            try dependencies.workspaceTrackingUseCases.addManualSession(
                for: project, task: task, startedAt: startedAt, endedAt: endedAt,
                in: modelContext, now: .now
            )
            return true
        } catch let trackingError as TrackingManagerError {
            errorMessage = trackingError.errorDescription
            return false
        } catch {
            errorMessage = "Der Zeiteintrag konnte nicht gespeichert werden."
            return false
        }
    }

    private func updateManualSession(_ session: WorkSession, task: ProjectTask?, startedAt: Date, endedAt: Date) -> Bool {
        do {
            try dependencies.workspaceTrackingUseCases.updateManualSession(
                session, task: task, startedAt: startedAt, endedAt: endedAt,
                in: modelContext, now: .now
            )
            trackingStatus.refresh()
            return true
        } catch let trackingError as TrackingManagerError {
            errorMessage = trackingError.errorDescription
            return false
        } catch {
            errorMessage = "Der Zeiteintrag konnte nicht aktualisiert werden."
            return false
        }
    }
}

// MARK: - Sidebar

struct MacSidebarPane: View {
    let projects: [ClientProject]
    let activeProjectId: UUID?
    @Binding var search: String
    @Binding var selectedId: UUID?
    let onAddProject: () -> Void

    @State private var collapsedClients: Set<String> = []

    private var grouped: [(client: String, items: [ClientProject])] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matched = q.isEmpty ? projects : projects.filter { p in
            p.displayName.lowercased().contains(q) || p.displayClientName.lowercased().contains(q)
        }
        return Dictionary(grouping: matched, by: \.displayClientName)
            .map { ($0.key, $0.value.sorted { $0.displayName < $1.displayName }) }
            .sorted { $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(TTColors.text3).font(.system(size: 11))
                TextField("Suchen", text: $search)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(TTColors.fill3)
            )
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(grouped, id: \.client) { group in
                        clientGroup(name: group.client, items: group.items)
                    }
                    Button(action: onAddProject) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus").font(.system(size: 11))
                            Text("Neuer Kunde").font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(TTColors.text2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
        }
        .background(.regularMaterial)
    }

    @ViewBuilder
    private func clientGroup(name: String, items: [ClientProject]) -> some View {
        let isOpen = !collapsedClients.contains(name)
        VStack(alignment: .leading, spacing: 1) {
            Button {
                if isOpen { collapsedClients.insert(name) } else { collapsedClients.remove(name) }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                    Text(name.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.6)
                    Spacer()
                }
                .foregroundStyle(TTColors.text2)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOpen {
                ForEach(items, id: \.id) { project in
                    projectRow(project)
                }
            }
        }
    }

    private func projectRow(_ project: ClientProject) -> some View {
        let selected = selectedId == project.id
        let totalMin = Int(project.sessionList.reduce(0.0) { $0 + $1.recordedDuration } / 60)
        return Button {
            selectedId = project.id
        } label: {
            HStack(spacing: 7) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(project.projectAccentColor)
                    .frame(width: 3, height: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(project.displayName)
                        .font(.system(size: 12, weight: selected ? .semibold : .medium))
                        .foregroundStyle(TTColors.text)
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        Text(project.displayClientName.uppercased())
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(0.3)
                            .foregroundStyle(TTColors.text3)
                        Circle().fill(TTColors.text3).frame(width: 2, height: 2)
                        Text(totalMin > 0 ? "\(totalMin / 60)h \(totalMin % 60)m" : "0m")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(TTColors.text3)
                    }
                }
                Spacer(minLength: 0)
                if activeProjectId == project.id {
                    PulseDot(color: TTColors.live, size: 6)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(selected ? TTColors.fill3 : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Aufnehmen pane

struct MacAufnehmenPane: View {
    let project: ClientProject
    let activeSession: WorkSession?
    let onStartTask: (ProjectTask) -> Void
    let onStartProject: () -> Void
    let onStop: () -> Void
    let onAddManualEntry: () -> Void
    let onEditEntry: (WorkSession) -> Void
    let onAddTask: (String) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var newTaskText: String = ""
    @State private var showRatePopover = false
    @State private var showBudgetPopover = false
    @State private var rateInputText = ""
    @State private var budgetInputText = ""
    @State private var budgetInputUnit: ProjectBudgetUnit = .hours

    private var isRunningOnThisProject: Bool {
        activeSession?.project?.id == project.id
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                SyncBanner(lastSyncedAt: nil)
                breadcrumb
                timerHero
                kpiGrid
                HStack(alignment: .top, spacing: 14) {
                    tasksCard.frame(maxWidth: .infinity)
                    entriesCard.frame(maxWidth: .infinity)
                }
            }
            .padding(16)
        }
    }

    private var breadcrumb: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(project.projectAccentColor)
                        .frame(width: 16, height: 16)
                    Text(String(project.displayClientName.prefix(1)).uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text("KUNDE · \(project.displayClientName.uppercased())")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.2)
                    .foregroundStyle(TTColors.text)
            }
            .padding(.leading, 5)
            .padding(.trailing, 9)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(project.projectAccentColor.opacity(0.10))
            )
            .overlay(
                Capsule().strokeBorder(project.projectAccentColor.opacity(0.25), lineWidth: 0.5)
            )

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(TTColors.text3)

            Text(project.displayName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(TTColors.text)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(TTColors.surface2)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(TTColors.text4, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var timerHero: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let live: TimeInterval = isRunningOnThisProject
                ? (activeSession.map { context.date.timeIntervalSince($0.startedAt) } ?? 0)
                : 0
            TimerHero(
                clientName: project.displayClientName,
                projectName: project.displayName,
                taskName: activeSession?.task?.displayTitle,
                projectColor: project.projectAccentColor,
                elapsed: live,
                hourlyRate: project.hourlyRate,
                billed: project.billedAmount(for: live),
                budgetProgress: nil,
                runningSinceLabel: isRunningOnThisProject ? activeSession.map { TimeFormatting.shortTime($0.startedAt) } : nil,
                compact: false,
                isThisRunning: isRunningOnThisProject,
                onStart: isRunningOnThisProject ? nil : onStartProject,
                onPause: isRunningOnThisProject ? onStop : nil,
                onStop: isRunningOnThisProject ? onStop : nil
            )
        }
    }

    private var kpiGrid: some View {
        let total = project.sessionList.reduce(0.0) { $0 + $1.recordedDuration }
        let value = project.billedAmount(for: total) ?? 0
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: .now)
        let today = project.sessionList.reduce(0.0) { acc, s in
            let start = max(s.startedAt, startOfDay)
            let end = s.endedAt ?? .now
            return acc + max(end.timeIntervalSince(start), 0)
        }

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
            StatTile("Gesamtzeit", value: TimeFormatting.compactDuration(total), sub: "\(project.sessionList.count) Einträge")
            StatTile("Gesamtwert", value: TimeFormatting.euroAmount(value), sub: "Zeit × Satz")
            StatTile("Heute", value: TimeFormatting.compactDuration(today), sub: "Seit 00:00")
            StatTile("Stundensatz", value: project.hourlyRate.map { TimeFormatting.euroAmount($0) } ?? "—", sub: "Pro Stunde", action: {
                rateInputText = project.hourlyRate.map { "\(Int($0))" } ?? ""
                showRatePopover = true
            })
            .popover(isPresented: $showRatePopover) { rateEditorPopover }

            StatTile("Budget", value: macBudgetDisplayValue, sub: macBudgetDisplaySub, action: {
                budgetInputUnit = project.budgetUnit ?? .hours
                budgetInputText = project.effectiveBudgetTarget.map { String(format: "%.0f", $0) } ?? ""
                showBudgetPopover = true
            })
            .popover(isPresented: $showBudgetPopover) { budgetEditorPopover }
        }
    }

    private var tasksCard: some View {
        SectionCard("Aufgaben · \(project.displayName)") {
            Text("\(project.sortedTasks.count) gesamt")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(TTColors.text3)
        } content: {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    TextField("Neue Aufgabe …", text: $newTaskText)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(TTColors.fill3)
                        )
                    Button("Hinzufügen") {
                        let title = newTaskText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !title.isEmpty else { return }
                        onAddTask(title)
                        newTaskText = ""
                    }
                    .buttonStyle(PillButtonStyle(variant: .primary, tint: project.projectAccentColor))
                    .frame(height: 32)
                }
                if project.sortedTasks.isEmpty {
                    Text("Noch keine Aufgaben")
                        .font(.system(size: 13))
                        .foregroundStyle(TTColors.text2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                } else {
                    ForEach(project.sortedTasks, id: \.id) { task in
                        let isRunning = isRunningOnThisProject && activeSession?.task?.id == task.id
                        let total = task.sessionList.reduce(0.0) { $0 + $1.recordedDuration }
                        TaskRow(
                            title: task.displayTitle,
                            projectColor: project.projectAccentColor,
                            entryCount: task.sessionList.count,
                            totalDuration: total,
                            hourlyRate: project.hourlyRate,
                            budgetProgress: nil,
                            isRunning: isRunning,
                            onPlayPause: {
                                if isRunning {
                                    onStop()
                                } else {
                                    onStartTask(task)
                                }
                            },
                            onAddEntry: onAddManualEntry,
                            onEdit: onAddManualEntry,
                            onShowEntries: onAddManualEntry
                        )
                    }
                }
            }
        }
    }

    private var entriesCard: some View {
        SectionCard("Letzte Einträge") {
            Button {
                onAddManualEntry()
            } label: {
                Label("Nachtragen", systemImage: "plus")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(TTColors.accent)
        } content: {
            let recent = Array(project.sortedSessions.prefix(8))
            if recent.isEmpty {
                Text("Noch keine Einträge")
                    .font(.system(size: 13))
                    .foregroundStyle(TTColors.text2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 0) {
                    ForEach(recent, id: \.id) { session in
                        EntryRow(
                            startEnd: timeRange(session),
                            projectColor: project.projectAccentColor,
                            taskName: session.displayTaskTitle,
                            clientName: project.displayClientName,
                            projectName: project.displayName,
                            duration: session.recordedDuration,
                            onTap: { onEditEntry(session) }
                        )
                        if session.id != recent.last?.id {
                            Divider().background(TTColors.separator)
                        }
                    }
                }
            }
        }
    }

    private func timeRange(_ session: WorkSession) -> String {
        let start = TimeFormatting.shortTime(session.startedAt)
        let end = session.endedAt.map { TimeFormatting.shortTime($0) } ?? "…"
        return "\(start)–\(end)"
    }

    @ViewBuilder
    private var rateEditorPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stundensatz").font(.headline)
            HStack(spacing: 8) {
                TextField("z. B. 85", text: $rateInputText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                Text("€/h").foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Button("Speichern") {
                    let n = rateInputText.replacingOccurrences(of: ",", with: ".")
                    if let v = Double(n), v > 0 {
                        project.hourlyRate = v
                    } else if rateInputText.trimmingCharacters(in: .whitespaces).isEmpty {
                        project.hourlyRate = nil
                    }
                    try? modelContext.save()
                    showRatePopover = false
                }
                .buttonStyle(.borderedProminent)
                .tint(project.projectAccentColor)
                Button("Abbrechen") { showRatePopover = false }
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(width: 220)
    }

    @ViewBuilder
    private var budgetEditorPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Budget").font(.headline)
            Picker("", selection: $budgetInputUnit) {
                Label("Stunden", systemImage: "clock").tag(ProjectBudgetUnit.hours)
                Label("Euro", systemImage: "eurosign.circle").tag(ProjectBudgetUnit.amount)
            }
            .pickerStyle(.segmented)
            HStack(spacing: 8) {
                TextField(budgetInputUnit == .hours ? "z. B. 20" : "z. B. 2500", text: $budgetInputText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                Text(budgetInputUnit == .hours ? "Std." : "EUR")
                    .foregroundStyle(.secondary)
            }
            if budgetInputUnit == .amount && !project.hasHourlyRate {
                Label("Stundensatz erforderlich.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            HStack(spacing: 8) {
                Button("Speichern") {
                    saveBudgetMac()
                    showBudgetPopover = false
                }
                .buttonStyle(.borderedProminent)
                .tint(project.projectAccentColor)
                .disabled(budgetInputUnit == .amount && !project.hasHourlyRate)
                if project.hasBudget {
                    Button("Entfernen", role: .destructive) {
                        project.clearBudget()
                        try? modelContext.save()
                        showBudgetPopover = false
                    }
                    .buttonStyle(.bordered)
                }
                Button("Abbrechen") { showBudgetPopover = false }
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(width: 260)
    }

    private func saveBudgetMac() {
        let n = budgetInputText.replacingOccurrences(of: ",", with: ".")
        if let v = Double(n), v > 0 {
            project.setBudget(unit: budgetInputUnit, target: v)
        } else {
            project.clearBudget()
        }
        try? modelContext.save()
    }

    private var macBudgetDisplayValue: String {
        guard let unit = project.budgetUnit, let target = project.effectiveBudgetTarget else {
            return "Offen"
        }
        switch unit {
        case .hours: return TimeFormatting.compactDuration(target * 3600)
        case .amount: return TimeFormatting.euroAmount(target)
        }
    }

    private var macBudgetDisplaySub: String {
        switch project.budgetUnit {
        case .hours: return "Std.-Budget"
        case .amount: return "€-Budget"
        case nil: return "Keine Grenze"
        }
    }
}

// MARK: - Auswertung pane

struct MacAuswertungPane: View {
    let projects: [ClientProject]

    @State private var topMode: AnalyticsTopProjectsDisplayMode = .bar
    @State private var exportErrorMessage: String?

    private var snapshot: AnalyticsAggregator.Snapshot {
        AnalyticsAggregator.snapshot(projects: projects)
    }

    var body: some View {
        let s = snapshot
        ScrollView {
            VStack(spacing: 14) {
                SyncBanner(lastSyncedAt: nil)
                header
                kpiGrid(s)
                topProjects(s)
                HStack(alignment: .top, spacing: 14) {
                    weekCard(s).frame(maxWidth: .infinity)
                    dayCard(s).frame(maxWidth: .infinity)
                }
            }
            .padding(16)
        }
        .alert("Export fehlgeschlagen", isPresented: exportAlertIsPresented) {
            Button("OK", role: .cancel) {
                exportErrorMessage = nil
            }
        } message: {
            Text(exportErrorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Auswertungen")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(TTColors.text)
                Text("Top-Projekte, Wochenstunden und tägliche Arbeitsverteilung auf einen Blick.")
                    .font(.system(size: 13))
                    .foregroundStyle(TTColors.text2)
            }
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "calendar").font(.system(size: 11))
                Text(monthLabel).font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(TTColors.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(TTColors.fill3))

            Menu {
                ForEach(AnalyticsExportService.supportedFormats) { format in
                    Button {
                        exportAnalytics(as: format)
                    } label: {
                        Label(format.title, systemImage: exportSystemImage(for: format))
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down").font(.system(size: 11))
                    Text("Exportieren").font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(TTColors.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(TTColors.fill3))
            }
#if os(macOS)
            .menuStyle(.borderlessButton)
#endif
        }
        .padding(20)
        .ttSurface(cornerRadius: 18)
    }

    private var monthLabel: String {
        Date.now.formatted(
            .dateTime
                .month(.wide)
                .year()
                .locale(Locale(identifier: "de_DE"))
        )
        .capitalized
    }

    private func kpiGrid(_ s: AnalyticsAggregator.Snapshot) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
            StatTile("Gesamtzeit", value: TimeFormatting.compactDuration(s.totalDuration), sub: "\(s.entryCount) Einträge")
            StatTile("Gesamtwert", value: TimeFormatting.euroAmount(s.totalValue), sub: "aus Zeit × Satz")
            StatTile("Diese Woche", value: TimeFormatting.compactDuration(s.weekDuration))
            StatTile("Heute", value: TimeFormatting.compactDuration(s.todayDuration), sub: "Seit 00:00")
        }
    }

    private func topProjects(_ s: AnalyticsAggregator.Snapshot) -> some View {
        SectionCard("Top-Projekte und Zeitverteilung") {
            HStack(spacing: 8) {
                Text("Darstellung")
                    .font(.system(size: 11))
                    .foregroundStyle(TTColors.text3)
                Picker("", selection: $topMode) {
                    ForEach(AnalyticsTopProjectsDisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }
        } content: {
            switch topMode.presentation(for: s.projectBars) {
            case .empty:
                VStack(spacing: 12) {
                    Text("Noch keine Daten")
                        .font(.system(size: 13))
                        .foregroundStyle(TTColors.text2)
                        .padding(.vertical, 8)
                }
            case .bars(let projectBars):
                VStack(spacing: 12) {
                    ForEach(projectBars, id: \.projectId) { agg in
                        ProjectBar(
                            projectColor: agg.color,
                            projectName: agg.projectName,
                            clientName: agg.clientName,
                            duration: agg.duration,
                            percentage: agg.percentage
                        )
                    }
                }
            case .pie(let projectBars):
                MacAnalyticsTopProjectsPieChart(projects: projectBars)
            }
        }
    }

    private var exportAlertIsPresented: Binding<Bool> {
        Binding(
            get: { exportErrorMessage != nil },
            set: { isPresented in
                if isPresented == false {
                    exportErrorMessage = nil
                }
            }
        )
    }

    private func exportSystemImage(for format: ProjectExportFormat) -> String {
        switch format {
        case .csv:
            return "tablecells"
        case .pdf:
            return "doc.richtext"
        }
    }

    private func exportAnalytics(as format: ProjectExportFormat) {
        let exportData = AnalyticsExportService.exportData(
            snapshot: snapshot,
            format: format,
            exportedAt: .now
        )

        guard exportData.isEmpty == false else {
            exportErrorMessage = "Der Export konnte nicht erstellt werden."
            return
        }

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.allowedContentTypes = [utType(for: format)]
        panel.nameFieldStringValue = AnalyticsExportService.defaultFileName(
            for: format,
            exportedAt: .now
        )

        guard panel.runModal() == .OK,
              let destinationURL = panel.url else {
            return
        }

        do {
            try exportData.write(to: destinationURL, options: .atomic)
        } catch {
            exportErrorMessage = "Die Exportdatei konnte nicht gespeichert werden."
        }
    }

    private func utType(for format: ProjectExportFormat) -> UTType {
        switch format {
        case .csv:
            return .commaSeparatedText
        case .pdf:
            return .pdf
        }
    }

    private func weekCard(_ s: AnalyticsAggregator.Snapshot) -> some View {
        SectionCard("Wochenstunden nach Projekten") {
            WeekBars(bars: s.weekBars).frame(height: 180)
        }
    }

    private func dayCard(_ s: AnalyticsAggregator.Snapshot) -> some View {
        SectionCard("Tagesprofil 0–24 Uhr") {
            DayProfile(buckets: s.day)
        }
    }
}

private struct MacAnalyticsTopProjectsPieChart: View {
    let projects: [AnalyticsAggregator.ProjectAggregate]

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            ZStack {
                ForEach(Array(pieSlices.enumerated()), id: \.offset) { _, slice in
                    Circle()
                        .trim(from: slice.start, to: slice.end)
                        .stroke(slice.color, lineWidth: 24)
                        .rotationEffect(.degrees(-90))
                }
            }
            .frame(width: 170, height: 170)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(projects.prefix(6), id: \.projectId) { project in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(project.color)
                            .frame(width: 10, height: 10)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(project.projectName)
                                .font(.headline)
                                .lineLimit(1)

                            Text(project.clientName)
                                .font(.caption)
                                .foregroundStyle(TTColors.text3)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 8)

                        Text(project.percentage, format: .percent.precision(.fractionLength(0)))
                            .font(.ttMono)
                            .font(.system(size: 12))
                            .foregroundStyle(TTColors.text2)
                    }
                }
            }
        }
    }

    private var pieSlices: [PieSlice] {
        var start: CGFloat = 0

        return projects.map { project in
            let end = start + CGFloat(project.percentage)
            let slice = PieSlice(start: start, end: end, color: project.color)
            start = end
            return slice
        }
    }

    private struct PieSlice {
        let start: CGFloat
        let end: CGFloat
        let color: Color
    }
}

#Preview("Mac redesigned root") {
    MacRedesignedRootPreviewHost()
        .frame(width: 1340, height: 860)
}

#Preview("Mac sidebar pane") {
    MacSidebarPanePreviewHost()
}

#Preview("Mac aufnehmen pane") {
    MacAufnehmenPanePreviewHost()
        .frame(width: 1080, height: 760)
}

#Preview("Mac auswertung pane") {
    MacAuswertungPanePreviewHost()
        .frame(width: 1080, height: 760)
}

@MainActor
private struct MacRedesignedRootPreviewHost: View {
    private let preview = PreviewWorkspaceSnapshot()

    var body: some View {
        MacRedesignedRootView(
            trackingStatus: preview.trackingStatus,
            dependencies: .live(configuration: TimeTrackerTargetConfiguration.macOS)
        )
        .modelContainer(preview.modelContainer)
    }
}

@MainActor
private struct MacSidebarPanePreviewHost: View {
    private let preview = PreviewWorkspaceSnapshot()
    @State private var search = ""
    @State private var selectedProjectID: UUID?

    var body: some View {
        MacSidebarPane(
            projects: preview.projects.filter { !$0.isArchived },
            activeProjectId: preview.activeSessions.first?.project?.id,
            search: $search,
            selectedId: $selectedProjectID,
            onAddProject: {}
        )
        .frame(width: 280, height: 700)
        .onAppear {
            if selectedProjectID == nil {
                selectedProjectID = preview.projects.first?.id
            }
        }
    }
}

@MainActor
private struct MacAufnehmenPanePreviewHost: View {
    private let preview = PreviewWorkspaceSnapshot()

    var body: some View {
        let project = preview.projects[0]

        MacAufnehmenPane(
            project: project,
            activeSession: preview.activeSessions.first,
            onStartTask: { _ in },
            onStartProject: {},
            onStop: {},
            onAddManualEntry: {},
            onEditEntry: { _ in },
            onAddTask: { _ in }
        )
    }
}

@MainActor
private struct MacAuswertungPanePreviewHost: View {
    private let preview = PreviewWorkspaceSnapshot()

    var body: some View {
        MacAuswertungPane(projects: preview.projects)
    }
}
