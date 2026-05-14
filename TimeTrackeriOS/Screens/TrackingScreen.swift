import SwiftData
import SwiftUI

struct TrackingScreen: View {
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
    @State private var selectedProjectID: UUID?
    @State private var quickAddText: String = ""
    @State private var sessionToEdit: WorkSession?
    @State private var manualEntryProject: ClientProject?
    @State private var errorMessage: String?
    @State private var showProjectsDrawer = false
    @State private var newProjectPresentation: NewProjectPresentation?
    @State private var showRateEditor = false
    @State private var rateInputText = ""

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
        ScrollView {
            VStack(spacing: 14) {
                SyncBanner(lastSyncedAt: nil)

                if let project = selectedProject {
                    timerHero(for: project)
                    if activeProjects.count > 1 {
                        ClientSwitcher(
                            items: switcherItems,
                            selectedId: project.id,
                            onSelect: { selectedProjectID = $0 }
                        )
                    }
                    statsGrid(for: project)
                    tasksSection(for: project)
                    entriesSection(for: project)
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(TTColors.bg.ignoresSafeArea())
        .environment(\.projectColorVariant, variant)
        .navigationTitle("Aufnehmen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Projekte", systemImage: "folder") {
                    showProjectsDrawer = true
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Projekt", systemImage: "plus") {
                    presentNewProjectSheet()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Darstellung", selection: $variantRaw) {
                        Text("Wash").tag(ProjectColorVariant.tinted.rawValue)
                        Text("Bar").tag(ProjectColorVariant.chromed.rawValue)
                    }
                } label: {
                    Label("Darstellung", systemImage: "paintpalette")
                }
            }
        }
        .navigationDestination(isPresented: $showProjectsDrawer) {
            ProjectsDrawer(
                projects: activeProjects,
                activeProjectId: activeSession?.project?.id,
                onSelect: { id in
                    selectedProjectID = id
                    showProjectsDrawer = false
                },
                onAddProject: { clientName in
                    presentNewProjectSheet(initialClientName: clientName)
                    showProjectsDrawer = false
                }
            )
        }
        .sheet(item: $newProjectPresentation) { presentation in
            NavigationStack {
                NewProjectSheet(
                    initialClientName: presentation.initialClientName,
                    onSave: saveProject
                )
            }
        }
        .sheet(item: $sessionToEdit) { session in
            if let project = session.project {
                NavigationStack {
                    ManualSessionSheet(
                        project: project,
                        sessionToEdit: session,
                        onSave: { start, end, task in
                            updateManualSession(session, task: task, startedAt: start, endedAt: end)
                        }
                    )
                }
            }
        }
        .sheet(item: $manualEntryProject) { project in
            NavigationStack {
                ManualSessionSheet(
                    project: project,
                    onSave: { start, end, task in
                        addManualSession(for: project, task: task, startedAt: start, endedAt: end)
                    }
                )
            }
        }
        .alert("Aktion fehlgeschlagen", isPresented: errorBinding, actions: {
            Button("OK", role: .cancel) { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "")
        })
        .alert("Stundensatz", isPresented: $showRateEditor) {
            TextField("z. B. 85", text: $rateInputText)
                .keyboardType(.decimalPad)
            Button("Speichern") {
                let normalized = rateInputText.replacingOccurrences(of: ",", with: ".")
                if let value = Double(normalized), value > 0 {
                    selectedProject?.hourlyRate = value
                } else if normalized.trimmingCharacters(in: .whitespaces).isEmpty {
                    selectedProject?.hourlyRate = nil
                }
                try? modelContext.save()
                rateInputText = ""
            }
            Button("Abbrechen", role: .cancel) { rateInputText = "" }
        } message: {
            Text("Gib den Stundensatz in € ein oder lass das Feld leer, um ihn zu entfernen.")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    // MARK: - Sections

    @ViewBuilder
    private func timerHero(for project: ClientProject) -> some View {
        let isThisRunning = activeSession?.project?.id == project.id
        let elapsed: TimeInterval = isThisRunning
            ? (activeSession.map { Date().timeIntervalSince($0.startedAt) } ?? 0)
            : 0

        TimelineView(.periodic(from: .now, by: 1)) { context in
            let live: TimeInterval = isThisRunning
                ? (activeSession.map { context.date.timeIntervalSince($0.startedAt) } ?? 0)
                : elapsed

            TimerHero(
                clientName: project.displayClientName,
                projectName: project.displayName,
                taskName: activeSession?.task?.displayTitle,
                projectColor: project.projectAccentColor,
                elapsed: live,
                hourlyRate: project.hourlyRate,
                billed: project.billedAmount(for: live),
                budgetProgress: project.budgetProgressFraction(for: totalProjectDuration(project, including: live, isRunning: isThisRunning)),
                runningSinceLabel: isThisRunning ? activeSession.map { TimeFormatting.shortTime($0.startedAt) } : nil,
                compact: true,
                isThisRunning: isThisRunning,
                onStart: isThisRunning ? nil : { startTracking(project: project, task: nil) },
                onPause: isThisRunning ? { stopActiveTracking() } : nil,
                onStop: isThisRunning ? { stopActiveTracking() } : nil
            )
            .opacity(isThisRunning ? 1 : 0.96)
        }
    }

    private func totalProjectDuration(_ project: ClientProject, including elapsed: TimeInterval, isRunning: Bool) -> TimeInterval {
        let stored = project.sessionList.filter { $0.endedAt != nil }.reduce(0.0) { $0 + $1.recordedDuration }
        return stored + (isRunning ? elapsed : 0)
    }

    private var switcherItems: [ClientSwitcher.Item] {
        activeProjects.prefix(20).map { p in
            ClientSwitcher.Item(
                id: p.id,
                clientName: p.displayClientName,
                projectName: p.displayName,
                projectColor: p.projectAccentColor,
                isRunning: activeSession?.project?.id == p.id
            )
        }
    }

    @ViewBuilder
    private func statsGrid(for project: ClientProject) -> some View {
        let total = project.sessionList.reduce(0.0) { $0 + $1.recordedDuration }
        let value = project.billedAmount(for: total) ?? 0
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: .now)
        let today = project.sessionList.reduce(0.0) { acc, s in
            guard s.startedAt >= startOfDay || s.endedAt == nil else { return acc }
            let start = max(s.startedAt, startOfDay)
            let end = s.endedAt ?? .now
            return acc + max(end.timeIntervalSince(start), 0)
        }

        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            StatTile("Gesamtzeit", value: TimeFormatting.compactDuration(total))
            StatTile("Gesamtwert", value: TimeFormatting.euroAmount(value))
            StatTile("Heute", value: TimeFormatting.compactDuration(today))
            Button {
                rateInputText = project.hourlyRate.map { "\(Int($0))" } ?? ""
                showRateEditor = true
            } label: {
                StatTile(
                    "Stundensatz",
                    value: project.hourlyRate.map { "\(Int($0)) €" } ?? "—"
                )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func tasksSection(for project: ClientProject) -> some View {
        SectionCard("Aufgaben") {
            VStack(spacing: 8) {
                quickAdd(for: project)
                if project.sortedTasks.isEmpty {
                    Text("Noch keine Aufgaben — füge oben eine hinzu.")
                        .font(.system(size: 13))
                        .foregroundStyle(TTColors.text2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                } else {
                    ForEach(project.sortedTasks, id: \.id) { task in
                        let isRunning = activeSession?.project?.id == project.id && activeSession?.task?.id == task.id
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
                                    stopActiveTracking()
                                } else {
                                    startTracking(project: project, task: task)
                                }
                            },
                            onAddEntry: {
                                manualEntryProject = project
                            },
                            onEdit: {
                                manualEntryProject = project
                            },
                            onShowEntries: {
                                manualEntryProject = project
                            }
                        )
                    }
                }
            }
        }
    }

    private func quickAdd(for project: ClientProject) -> some View {
        HStack(spacing: 8) {
            TextField("Neue Aufgabe", text: $quickAddText)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(
                    Capsule().fill(TTColors.fill3)
                )
            Button {
                addQuickTask(to: project)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(PillButtonStyle(variant: .tinted, tint: project.projectAccentColor))
        }
    }

    @ViewBuilder
    private func entriesSection(for project: ClientProject) -> some View {
        let recent = project.sortedSessions.prefix(8)
        if recent.isEmpty {
            EmptyView()
        } else {
            SectionCard("Letzte Einträge") {
                VStack(spacing: 0) {
                    ForEach(Array(recent), id: \.id) { session in
                        EntryRow(
                            startEnd: timeRange(session),
                            projectColor: project.projectAccentColor,
                            taskName: session.displayTaskTitle,
                            clientName: project.displayClientName,
                            projectName: project.displayName,
                            duration: session.recordedDuration,
                            onTap: { sessionToEdit = session }
                        )
                        if session.id != recent.last?.id {
                            Divider().background(TTColors.separator)
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundStyle(TTColors.text3)
            Text("Noch keine Projekte")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(TTColors.text)
            Text("Lege ein Projekt an, um mit der Zeiterfassung zu beginnen.")
                .font(.system(size: 13))
                .foregroundStyle(TTColors.text2)
                .multilineTextAlignment(.center)
            PillButton("Projekt anlegen", systemImage: "plus", variant: .primary, tint: ClientProject.primaryActionColor) {
                presentNewProjectSheet()
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .ttSurface(cornerRadius: TTRadius.lg)
    }

    private func timeRange(_ session: WorkSession) -> String {
        let start = TimeFormatting.shortTime(session.startedAt)
        let end = session.endedAt.map { TimeFormatting.shortTime($0) } ?? "…"
        return "\(start)–\(end)"
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

    private func addQuickTask(to project: ClientProject) {
        let title = quickAddText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let task = ProjectTask(title: title, project: project)
        modelContext.insert(task)
        try? modelContext.save()
        quickAddText = ""
    }

    private func presentNewProjectSheet(initialClientName: String = "") {
        newProjectPresentation = NewProjectPresentation(initialClientName: initialClientName)
    }

    private func saveProject(_ project: ClientProject) -> Bool {
        modelContext.insert(project)

        do {
            try modelContext.save()
            selectedProjectID = project.id
            trackingStatus.refresh()
            return true
        } catch {
            modelContext.delete(project)
            errorMessage = "Das Projekt konnte nicht gespeichert werden."
            return false
        }
    }
}

private struct NewProjectPresentation: Identifiable {
    let id = UUID()
    let initialClientName: String
}

#Preview("Tracking screen") {
    NavigationStack {
        TrackingScreenPreviewHost()
    }
}

@MainActor
private struct TrackingScreenPreviewHost: View {
    private let preview = PreviewWorkspaceSnapshot()

    var body: some View {
        TrackingScreen(
            trackingStatus: preview.trackingStatus,
            dependencies: .preview
        )
        .modelContainer(preview.modelContainer)
    }
}
