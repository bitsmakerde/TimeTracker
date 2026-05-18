import SwiftData
import SwiftUI

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
    @State private var viewModel = MacRedesignedRootViewModel()

    private var variant: ProjectColorVariant {
        ProjectColorVariant(rawValue: variantRaw) ?? .chromed
    }

    private var activeProjects: [ClientProject] {
        viewModel.activeProjects(from: projects)
    }

    private var activeSession: WorkSession? {
        viewModel.activeSession(from: activeSessions)
    }

    private var selectedProject: ClientProject? {
        viewModel.selectedProject(from: projects, activeSession: activeSession)
    }

    var body: some View {
        NavigationSplitView {
            MacSidebarPane(
                projects: activeProjects,
                activeProjectId: activeSession?.project?.id,
                search: $viewModel.search,
                selectedId: $viewModel.selectedProjectID,
                onAddProject: { viewModel.presentingNewProject = true }
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
        .toolbar { toolbarContent }
        .sheet(isPresented: $viewModel.presentingNewProject) { newProjectSheet }
        .sheet(item: $viewModel.manualEntryProject) { project in
            ManualSessionSheet(project: project) { start, end, task in
                addManualSession(for: project, task: task, startedAt: start, endedAt: end)
            }
        }
        .sheet(item: $viewModel.sessionToEdit) { session in
            if let project = session.project {
                ManualSessionSheet(project: project, sessionToEdit: session) { start, end, task in
                    updateManualSession(session, task: task, startedAt: start, endedAt: end)
                }
            }
        }
        .sheet(item: $viewModel.taskToEdit) { task in
            TaskEditorSheet(
                task: task,
                onSaveTaskTitle: { title in
                    saveTaskTitle(title, for: task)
                },
                onAddEntry: { startedAt, endedAt in
                    addManualSession(for: task, startedAt: startedAt, endedAt: endedAt)
                },
                onUpdateEntry: { session, startedAt, endedAt in
                    updateManualSession(session, task: task, startedAt: startedAt, endedAt: endedAt)
                },
                onDeleteTask: { task in
                    deleteTask(task)
                },
                onDeleteEntry: { session in
                    deleteSession(session)
                }
            )
        }
        .alert("Aktion fehlgeschlagen", isPresented: $viewModel.errorIsPresented) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HStack(spacing: 4) {
                if macMode == "rec" {
                    Button(action: { macMode = "rec" }) {
                        HStack {
                            Image(systemName: "chart.bar.xaxis")
                            Text("Erfassen")
                        }
                    }
                    .buttonStyle(.glass)
                } else {
                    Button(action: { macMode = "rec" }) {
                        HStack {
                            Image(systemName: "chart.bar.xaxis")
                            Text("Erfassen")
                        }
                        .padding(.horizontal, 8)
                    }
                    .buttonStyle(.bordered)
                }

                if macMode == "rep" {
                    Button(action: { macMode = "rep" }) {
                        HStack {
                            Image(systemName: "chart.bar.xaxis")
                            Text("Auswertung")
                        }
                    }
                    .buttonStyle(.glass)
                } else {
                    Button(action: { macMode = "rep" }) {
                        HStack {
                            Image(systemName: "chart.bar.xaxis")
                            Text("Auswertung")
                        }
                        .padding(.horizontal, 8)
                    }
                    .buttonStyle(.bordered)
                }
            }
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
            SyncBanner(
                syncStatus: trackingStatus.syncStatus,
                presentation: .compactExpandable
            )
        }
    }

    private var newProjectSheet: some View {
        NewProjectSheet(initialClientName: "") { project in
            modelContext.insert(project)
            do {
                try modelContext.save()
                viewModel.selectCreatedProject(project)
                return true
            } catch {
                modelContext.delete(project)
                viewModel.errorMessage = "Das Projekt konnte nicht gespeichert werden."
                return false
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let project = selectedProject {
            if macMode == "rep" {
                MacAuswertungPane(
                    projects: projects,
                    syncStatus: trackingStatus.syncStatus
                )
            } else {
                MacAufnehmenPane(
                    project: project,
                    activeSession: activeSession,
                    onStartTask: { task in startTracking(project: project, task: task) },
                    onStartProject: { startTracking(project: project, task: nil) },
                    onStop: stopActiveTracking,
                    onAddManualEntry: { viewModel.manualEntryProject = project },
                    onEditEntry: { session in viewModel.sessionToEdit = session },
                    onEditTask: { task in viewModel.taskToEdit = task },
                    onAddTask: { title in
                        let task = ProjectTask(title: title, project: project)
                        modelContext.insert(task)
                        try? modelContext.save()
                    }
                )
            }
        } else {
            ContentUnavailableView(
                "Noch keine Projekte",
                systemImage: "tray",
                description: Text("Lege ein Projekt an, um mit der Zeiterfassung zu starten.")
            )
            .toolbar {
                Button("Projekt anlegen", action: { viewModel.presentingNewProject = true })
            }
        }
    }

    private func startTracking(project: ClientProject, task: ProjectTask?) {
        do {
            try dependencies.workspaceTrackingUseCases.startTracking(
                project: project, task: task, in: modelContext, at: .now
            )
            trackingStatus.refresh()
        } catch let trackingError as TrackingManagerError {
            viewModel.errorMessage = trackingError.errorDescription
        } catch {
            viewModel.errorMessage = "Die Zeiterfassung konnte nicht gestartet werden."
        }
    }

    private func stopActiveTracking() {
        do {
            try dependencies.workspaceTrackingUseCases.stopActiveTracking(in: modelContext, at: .now)
            trackingStatus.refresh()
        } catch {
            viewModel.errorMessage = "Die laufende Zeiterfassung konnte nicht beendet werden."
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
            viewModel.errorMessage = trackingError.errorDescription
            return false
        } catch {
            viewModel.errorMessage = "Der Zeiteintrag konnte nicht gespeichert werden."
            return false
        }
    }

    private func addManualSession(for task: ProjectTask, startedAt: Date, endedAt: Date) -> Bool {
        guard let project = task.project else {
            viewModel.errorMessage = "Die Aufgabe ist keinem Projekt mehr zugeordnet."
            return false
        }

        return addManualSession(
            for: project,
            task: task,
            startedAt: startedAt,
            endedAt: endedAt
        )
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
            viewModel.errorMessage = trackingError.errorDescription
            return false
        } catch {
            viewModel.errorMessage = "Der Zeiteintrag konnte nicht aktualisiert werden."
            return false
        }
    }

    private func deleteSession(_ session: WorkSession) -> Bool {
        do {
            try dependencies.workspaceTrackingUseCases.deleteSession(session, in: modelContext)
            trackingStatus.refresh()
            return true
        } catch {
            viewModel.errorMessage = "Der Zeiteintrag konnte nicht entfernt werden."
            return false
        }
    }

    private func deleteTask(_ task: ProjectTask) -> Bool {
        do {
            try dependencies.workspaceTrackingUseCases.deleteTask(task, in: modelContext)
            viewModel.clearTaskEditorIfNeeded(deletedTaskID: task.id)
            trackingStatus.refresh()
            return true
        } catch {
            viewModel.errorMessage = ProjectDetailLogic.taskEditorTaskDeleteErrorMessage()
            return false
        }
    }

    private func saveTaskTitle(_ title: String, for task: ProjectTask) -> Bool {
        let normalizedTitle = ProjectDetailLogic.normalizedTaskTitle(title)
        guard ProjectDetailLogic.taskTitleValidationMessage(normalizedTitle) == nil else {
            return false
        }

        let previousTitle = task.title
        task.title = normalizedTitle

        do {
            try modelContext.save()
            return true
        } catch {
            task.title = previousTitle
            viewModel.errorMessage = "Die Aufgabe konnte nicht gespeichert werden."
            return false
        }
    }
}

private struct MacModeToolbarButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(title, systemImage: systemImage, action: action)
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(isSelected ? .white : .primary)
            .background {
                if isSelected {
                    Capsule().fill(.tint)
                } else {
                    Capsule().fill(.quaternary)
                }
            }
            .overlay {
                Capsule().stroke(isSelected ? .clear : .secondary.opacity(0.25))
            }
            .contentShape(.capsule)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview("Mac redesigned root") {
    MacRedesignedRootPreviewHost()
        .frame(width: 1340, height: 860)
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
