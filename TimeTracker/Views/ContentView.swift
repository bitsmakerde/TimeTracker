import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    let trackingStatus: TrackingStatusStore

    @Query(
        sort: [
            SortDescriptor(\ClientProject.clientName),
            SortDescriptor(\ClientProject.name),
        ]
    )
    private var projects: [ClientProject]

    @Query(
        filter: #Predicate<WorkSession> { session in
            session.endedAt == nil
        },
        sort: [SortDescriptor(\WorkSession.startedAt, order: .reverse)]
    )
    private var activeSessions: [WorkSession]

    @State private var selectedProjectID: UUID?
    @State private var isPresentingNewProjectSheet = false
    @State private var isPresentingManualSessionSheet = false
    @State private var sessionEditor: SessionEditor?
    @State private var initialClientNameForNewProject = ""
    @State private var errorMessage: String?

    private let trackingManager = TrackingManager()

    private var activeSession: WorkSession? {
        activeSessions.first
    }

    private var activeProjects: [ClientProject] {
        projects.filter { !$0.isArchived }
    }

    private var archivedProjects: [ClientProject] {
        projects
            .filter(\.isArchived)
            .sorted { lhs, rhs in
                let lhsArchivedAt = lhs.archivedAt ?? .distantPast
                let rhsArchivedAt = rhs.archivedAt ?? .distantPast

                if lhsArchivedAt == rhsArchivedAt {
                    let clientComparison = lhs.displayClientName.localizedCaseInsensitiveCompare(rhs.displayClientName)

                    if clientComparison == .orderedSame {
                        return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
                    }

                    return clientComparison == .orderedAscending
                }

                return lhsArchivedAt > rhsArchivedAt
            }
    }

    private var groupedProjects: [ClientGroup] {
        Dictionary(grouping: activeProjects, by: \.displayClientName)
            .map { key, value in
                ClientGroup(
                    displayName: key,
                    rawClientName: value.first?.clientName.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                    projects: value.sorted {
                        $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                    }
                )
            }
            .sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
    }

    private var selectedProject: ClientProject? {
        guard let selectedProjectID else {
            return projects.first
        }

        return projects.first { $0.id == selectedProjectID }
    }

    private var alertIsPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    errorMessage = nil
                }
            }
        )
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $isPresentingNewProjectSheet) {
            NewProjectSheet(initialClientName: initialClientNameForNewProject) { project in
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
        .sheet(isPresented: $isPresentingManualSessionSheet) {
            if let selectedProject {
                ManualSessionSheet(project: selectedProject) { startedAt, endedAt, task in
                    addManualSession(
                        for: selectedProject,
                        task: task,
                        startedAt: startedAt,
                        endedAt: endedAt
                    )
                }
            }
        }
        .sheet(item: $sessionEditor) { editor in
            ManualSessionSheet(
                project: editor.project,
                sessionToEdit: editor.session
            ) { startedAt, endedAt, task in
                updateManualSession(
                    editor.session,
                    task: task,
                    startedAt: startedAt,
                    endedAt: endedAt
                )
            }
        }
        .alert("Aktion fehlgeschlagen", isPresented: alertIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear {
            if selectedProjectID == nil {
                selectedProjectID = projects.first?.id
            }
        }
        .onChange(of: projects.map(\.id)) { _, projectIDs in
            if selectedProjectID == nil || !projectIDs.contains(selectedProjectID ?? UUID()) {
                selectedProjectID = projectIDs.first
            }
        }
    }

    private var sidebar: some View {
        List(selection: $selectedProjectID) {
            if let activeSession, let project = activeSession.project {
                Section("Aktive Zeiterfassung") {
                    ActiveSidebarCard(
                        project: project,
                        session: activeSession,
                        task: activeSession.task,
                        onStop: stopActiveTracking
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                    .listRowBackground(Color.clear)
                }
            }

            ForEach(groupedProjects, id: \.client) { group in
                Section {
                    ForEach(group.projects) { project in
                        ProjectSidebarRow(
                            project: project,
                            isActive: activeSession?.project?.id == project.id,
                            isArchived: false
                        )
                        .tag(project.id)
                    }
                } header: {
                    ClientSectionHeader(
                        title: group.displayName,
                        onAddProject: {
                            presentNewProjectSheet(for: group.rawClientName)
                        }
                    )
                }
            }

            if !archivedProjects.isEmpty {
                Section("Archiv") {
                    ForEach(archivedProjects) { project in
                        ProjectSidebarRow(
                            project: project,
                            isActive: false,
                            isArchived: true
                        )
                        .tag(project.id)
                    }
                }
            }
        }
        .navigationTitle("Zeittracker")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    presentNewProjectSheet()
                } label: {
                    Label("Projekt", systemImage: "plus")
                }

                if activeSession != nil {
                    Button(role: .destructive) {
                        stopActiveTracking()
                    } label: {
                        Label("Stopp", systemImage: "stop.fill")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if let selectedProject {
            ProjectDetailView(
                project: selectedProject,
                activeSession: activeSession,
                onStart: { startTracking(selectedProject) },
                onStartTask: { task in
                    startTracking(selectedProject, task: task)
                },
                onStop: stopActiveTracking,
                onAddManualEntry: {
                    isPresentingManualSessionSheet = true
                },
                onEditSession: { session in
                    sessionEditor = SessionEditor(
                        project: selectedProject,
                        session: session
                    )
                },
                onDeleteSession: deleteSession,
                onArchiveProject: {
                    archiveProject(selectedProject)
                },
                onRestoreProject: {
                    restoreProject(selectedProject)
                },
                onDeleteProject: {
                    deleteProject(selectedProject)
                }
            )
        } else {
            EmptyStateView {
                presentNewProjectSheet()
            }
        }
    }

    private func startTracking(
        _ project: ClientProject,
        task: ProjectTask? = nil
    ) {
        do {
            try trackingManager.startTracking(
                project: project,
                task: task,
                in: modelContext
            )
            trackingStatus.refresh()
        } catch let trackingError as TrackingManagerError {
            errorMessage = trackingError.errorDescription
        } catch {
            errorMessage = "Die Zeiterfassung fuer dieses Projekt konnte nicht gestartet werden."
        }
    }

    private func stopActiveTracking() {
        do {
            try trackingManager.stopActiveTracking(in: modelContext)
            trackingStatus.refresh()
        } catch {
            errorMessage = "Die laufende Zeiterfassung konnte nicht beendet werden."
        }
    }

    private func addManualSession(
        for project: ClientProject,
        task: ProjectTask?,
        startedAt: Date,
        endedAt: Date
    ) -> Bool {
        do {
            try trackingManager.addManualSession(
                for: project,
                task: task,
                startedAt: startedAt,
                endedAt: endedAt,
                in: modelContext
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

    private func updateManualSession(
        _ session: WorkSession,
        task: ProjectTask?,
        startedAt: Date,
        endedAt: Date
    ) -> Bool {
        do {
            try trackingManager.updateManualSession(
                session,
                task: task,
                startedAt: startedAt,
                endedAt: endedAt,
                in: modelContext
            )
            return true
        } catch let trackingError as TrackingManagerError {
            errorMessage = trackingError.errorDescription
            return false
        } catch {
            errorMessage = "Der Zeiteintrag konnte nicht aktualisiert werden."
            return false
        }
    }

    private func deleteSession(_ session: WorkSession) {
        do {
            try trackingManager.deleteSession(session, in: modelContext)

            if sessionEditor?.session.id == session.id {
                sessionEditor = nil
            }

            trackingStatus.refresh()
        } catch {
            errorMessage = "Der Zeiteintrag konnte nicht geloescht werden."
        }
    }

    private func archiveProject(_ project: ClientProject) {
        do {
            try trackingManager.archiveProject(project, in: modelContext)
            trackingStatus.refresh()
        } catch let trackingError as TrackingManagerError {
            errorMessage = trackingError.errorDescription
        } catch {
            errorMessage = "Das Projekt konnte nicht archiviert werden."
        }
    }

    private func restoreProject(_ project: ClientProject) {
        do {
            try trackingManager.restoreProject(project, in: modelContext)
            trackingStatus.refresh()
        } catch {
            errorMessage = "Das Projekt konnte nicht reaktiviert werden."
        }
    }

    private func deleteProject(_ project: ClientProject) {
        let deletedProjectID = project.id

        do {
            try trackingManager.deleteProject(project, in: modelContext)

            if selectedProjectID == deletedProjectID {
                selectedProjectID = nil
            }

            trackingStatus.refresh()
        } catch {
            errorMessage = "Das Projekt konnte nicht geloescht werden."
        }
    }

    private func presentNewProjectSheet(for clientName: String = "") {
        initialClientNameForNewProject = clientName
        isPresentingNewProjectSheet = true
    }
}

private struct ClientGroup {
    let displayName: String
    let rawClientName: String
    let projects: [ClientProject]

    var client: String {
        displayName
    }
}

private struct SessionEditor: Identifiable {
    let project: ClientProject
    let session: WorkSession

    var id: UUID {
        session.id
    }
}

private struct ClientSectionHeader: View {
    let title: String
    let onAddProject: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(.caption.weight(.semibold))

            Spacer()

            Button(action: onAddProject) {
                Image(systemName: "plus")
                    .font(.caption.weight(.bold))
            }
            .buttonStyle(.borderless)
            .help("Projekt zu diesem Kunden hinzufuegen")
        }
    }
}

private struct ProjectSidebarRow: View {
    let project: ClientProject
    let isActive: Bool
    let isArchived: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(accentColor)
                    .frame(width: 8, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.displayName)
                        .font(.headline)

                    Text(project.displayClientName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isActive {
                    Image(systemName: "play.circle.fill")
                        .foregroundStyle(.teal)
                } else if isArchived {
                    Image(systemName: "archivebox.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var accentColor: Color {
        if isActive {
            return .teal
        }

        if isArchived {
            return Color.gray.opacity(0.75)
        }

        return Color.orange.opacity(0.8)
    }
}

private struct ActiveSidebarCard: View {
    let project: ClientProject
    let session: WorkSession
    let task: ProjectTask?
    let onStop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Gerade aktiv")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(project.displayName)
                .font(.headline)

            Text(project.displayClientName)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let task {
                Text(task.displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.teal)
            } else {
                Text("Ohne Aufgabe")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                Text(TimeFormatting.digitalDuration(session.duration(referenceDate: timeline.date)))
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }

            Button("Tracking stoppen", role: .destructive, action: onStop)
                .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.teal.opacity(0.16), Color.orange.opacity(0.14)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}

private struct EmptyStateView: View {
    let onAddProject: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color.teal.opacity(0.06),
                    Color.orange.opacity(0.05),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                Text("Zeiten pro Kundenprojekt erfassen")
                    .font(.system(size: 34, weight: .bold, design: .rounded))

                Text("Lege dein erstes Projekt an und starte die Zeiterfassung direkt aus der Uebersicht.")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Button("Projekt anlegen", action: onAddProject)
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: 460, alignment: .leading)
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.background.opacity(0.88))
                    .shadow(color: .black.opacity(0.06), radius: 20, x: 0, y: 12)
            )
        }
    }
}
