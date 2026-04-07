import SwiftData
import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

struct WorkspaceRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let trackingStatus: TrackingStatusStore
    let dependencies: AppDependencies
    let forcedWorkspaceSection: WorkspaceSection?
    let showsWorkspaceSectionPicker: Bool

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
    @State private var selectedWorkspaceSection: WorkspaceSection = .tracking
    @State private var isPresentingNewProjectSheet = false
    @State private var isPresentingManualSessionSheet = false
    @State private var sessionEditor: SessionEditor?
    @State private var initialClientNameForNewProject = ""
    @State private var errorMessage: String?

    private var activeSession: WorkSession? {
        activeSessions.first
    }

    private var activeWorkspaceSection: WorkspaceSection {
        forcedWorkspaceSection ?? selectedWorkspaceSection
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
        workspaceLayout
            .sheet(isPresented: $isPresentingNewProjectSheet, content: newProjectSheet)
            .sheet(isPresented: $isPresentingManualSessionSheet, content: manualSessionSheet)
            .sheet(item: $sessionEditor, content: sessionEditorSheet(editor:))
            .alert(
                "Aktion fehlgeschlagen",
                isPresented: alertIsPresented,
                actions: alertActions,
                message: alertMessage
            )
            .onAppear(perform: ensureInitialSelection)
            .onChange(of: projectIDList) { _, projectIDs in
                synchronizeSelection(with: projectIDs)
            }
    }

    init(
        trackingStatus: TrackingStatusStore,
        dependencies: AppDependencies,
        forcedWorkspaceSection: WorkspaceSection? = nil,
        showsWorkspaceSectionPicker: Bool = true
    ) {
        self.trackingStatus = trackingStatus
        self.dependencies = dependencies
        self.forcedWorkspaceSection = forcedWorkspaceSection
        self.showsWorkspaceSectionPicker = showsWorkspaceSectionPicker
    }

    @ViewBuilder
    private var workspaceLayout: some View {
#if os(iOS)
        if WorkspaceRootLayoutRules.usesTabRoot(
            horizontalSizeClass: horizontalSizeClass,
            forcedWorkspaceSection: forcedWorkspaceSection,
            prefersNativeTabBar: dependencies.configuration.featureFlags.usesNativeCompactTabBar
        ) {
            iosCompactTabLayout
        } else if horizontalSizeClass == .compact {
            NavigationStack {
                detailArea(
                    for: activeWorkspaceSection,
                    showsWorkspaceTabBar: false
                )
                .navigationTitle(activeWorkspaceSection.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(content: iosCompactToolbar)
            }
        } else {
            navigationLayout(
                for: activeWorkspaceSection,
                showsWorkspaceTabBar: showsWorkspaceSectionPicker && forcedWorkspaceSection == nil
            )
        }
#else
        navigationLayout(
            for: activeWorkspaceSection,
            showsWorkspaceTabBar: showsWorkspaceSectionPicker && forcedWorkspaceSection == nil
        )
#endif
    }

#if os(iOS)
    private var iosCompactTabLayout: some View {
        TabView(selection: $selectedWorkspaceSection) {
            Tab(
                WorkspaceSection.tracking.title,
                systemImage: WorkspaceSection.tracking.systemImage,
                value: WorkspaceSection.tracking
            ) {
                NavigationStack {
                    trackingDetailContent
                        .navigationTitle(WorkspaceSection.tracking.title)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar(content: iosCompactToolbar)
                }
            }

            Tab(
                WorkspaceSection.analytics.title,
                systemImage: WorkspaceSection.analytics.systemImage,
                value: WorkspaceSection.analytics
            ) {
                NavigationStack {
                    AnalyticsOverviewView(projects: projects)
                        .navigationTitle(WorkspaceSection.analytics.title)
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
    }
#endif

    private func navigationLayout(
        for section: WorkspaceSection,
        showsWorkspaceTabBar: Bool
    ) -> some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailArea(
                for: section,
                showsWorkspaceTabBar: showsWorkspaceTabBar
            )
        }
        .navigationSplitViewStyle(.balanced)
    }

#if os(iOS)
    @ToolbarContentBuilder
    private func iosCompactToolbar() -> some ToolbarContent {
        if activeWorkspaceSection == .tracking {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    if activeProjects.isEmpty {
                        Text("Keine Projekte")
                    } else {
                        ForEach(activeProjects) { project in
                            Button {
                                selectedProjectID = project.id
                            } label: {
                                Label(
                                    project.displayName,
                                    systemImage: selectedProjectID == project.id ? "checkmark" : "circle"
                                )
                            }
                        }
                    }
                } label: {
                    Label("Projekt", systemImage: "folder")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    presentNewProjectSheet()
                } label: {
                    Label("Projekt", systemImage: "plus")
                }
            }

            if activeSession != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        stopActiveTracking()
                    } label: {
                        Label("Stopp", systemImage: "stop.fill")
                    }
                }
            }
        }
    }
#endif

    private func newProjectSheet() -> some View {
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

    @ViewBuilder
    private func manualSessionSheet() -> some View {
        if let selectedProject {
            ManualSessionSheet(project: selectedProject) { startedAt, endedAt, task in
                addManualSession(
                    for: selectedProject,
                    task: task,
                    startedAt: startedAt,
                    endedAt: endedAt
                )
            }
        } else {
            EmptyView()
        }
    }

    private func sessionEditorSheet(editor: SessionEditor) -> some View {
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

    private func alertActions() -> some View {
        Button("OK", role: .cancel) {}
    }

    private func alertMessage() -> some View {
        Text(errorMessage ?? "")
    }

    private var projectIDList: [UUID] {
        projects.map { $0.id }
    }

    private func ensureInitialSelection() {
        if selectedProjectID == nil {
            selectedProjectID = projects.first?.id
        }
    }

    private func synchronizeSelection(with projectIDs: [UUID]) {
        if let selectedProjectID,
           !projectIDs.contains(selectedProjectID) {
            self.selectedProjectID = projectIDs.first
            return
        }

        if selectedProjectID == nil {
            selectedProjectID = projectIDs.first
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
    private func detailArea(
        for section: WorkspaceSection,
        showsWorkspaceTabBar: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsWorkspaceTabBar {
                workspaceTabBar
            }

            if section == .analytics {
                AnalyticsOverviewView(projects: projects)
            } else {
                trackingDetailContent
            }
        }
    }

    private var workspaceTabBar: some View {
        HStack {
            Spacer(minLength: 0)

            HStack(spacing: 8) {
                ForEach(WorkspaceSection.allCases) { section in
                    WorkspaceTabButton(
                        title: section.title,
                        systemImage: section.systemImage,
                        isSelected: selectedWorkspaceSection == section
                    ) {
                        selectedWorkspaceSection = section
                    }
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .clipShape(.rect(cornerRadius: 16, style: .continuous))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var trackingDetailContent: some View {
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
            try dependencies.workspaceTrackingUseCases.startTracking(
                project: project,
                task: task,
                in: modelContext,
                at: .now
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
            try dependencies.workspaceTrackingUseCases.stopActiveTracking(
                in: modelContext,
                at: .now
            )
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
            try dependencies.workspaceTrackingUseCases.addManualSession(
                for: project,
                task: task,
                startedAt: startedAt,
                endedAt: endedAt,
                in: modelContext,
                now: .now
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
            try dependencies.workspaceTrackingUseCases.updateManualSession(
                session,
                task: task,
                startedAt: startedAt,
                endedAt: endedAt,
                in: modelContext,
                now: .now
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
            try dependencies.workspaceTrackingUseCases.deleteSession(
                session,
                in: modelContext
            )

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
            try dependencies.workspaceTrackingUseCases.archiveProject(
                project,
                in: modelContext,
                at: .now
            )
            trackingStatus.refresh()
        } catch let trackingError as TrackingManagerError {
            errorMessage = trackingError.errorDescription
        } catch {
            errorMessage = "Das Projekt konnte nicht archiviert werden."
        }
    }

    private func restoreProject(_ project: ClientProject) {
        do {
            try dependencies.workspaceTrackingUseCases.restoreProject(
                project,
                in: modelContext
            )
            trackingStatus.refresh()
        } catch {
            errorMessage = "Das Projekt konnte nicht reaktiviert werden."
        }
    }

    private func deleteProject(_ project: ClientProject) {
        let deletedProjectID = project.id

        do {
            try dependencies.workspaceTrackingUseCases.deleteProject(
                project,
                in: modelContext
            )

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

enum WorkspaceSection: String, CaseIterable, Identifiable {
    case tracking
    case analytics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tracking:
            return "Aufnehmen"
        case .analytics:
            return "Auswertung"
        }
    }

    var systemImage: String {
        switch self {
        case .tracking:
            return "record.circle"
        case .analytics:
            return "chart.bar.xaxis"
        }
    }
}

struct WorkspaceRootLayoutRules {
    static func usesTabRoot(
        horizontalSizeClass: UserInterfaceSizeClass?,
        forcedWorkspaceSection: WorkspaceSection?,
        prefersNativeTabBar: Bool
    ) -> Bool {
        prefersNativeTabBar && horizontalSizeClass == .compact && forcedWorkspaceSection == nil
    }
}

private struct WorkspaceTabButton: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(minWidth: horizontalSizeClass == .compact ? nil : 160)
                .frame(maxWidth: horizontalSizeClass == .compact ? .infinity : nil)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .foregroundStyle(labelStyle)
        .background(backgroundStyle)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(strokeStyle, lineWidth: 1)
        )
        .clipShape(.rect(cornerRadius: 12, style: .continuous))
    }

    private var labelStyle: Color {
        if isSelected {
            return colorScheme == .dark ? Color.white.opacity(0.95) : Color.black.opacity(0.88)
        }

        return colorScheme == .dark ? Color.white.opacity(0.72) : Color.black.opacity(0.66)
    }

    private var backgroundStyle: Color {
        if isSelected {
            return colorScheme == .dark
                ? Color.teal.opacity(0.22)
                : Color.teal.opacity(0.14)
        }

        return colorScheme == .dark
            ? Color.white.opacity(0.04)
            : Color.white.opacity(0.86)
    }

    private var strokeStyle: Color {
        if isSelected {
            return Color.teal.opacity(0.65)
        }

        return colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.08)
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
                        .foregroundStyle(accentColor)
                } else if isArchived {
                    Image(systemName: "archivebox.fill")
                        .foregroundStyle(accentColor)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var accentColor: Color {
        if isArchived {
            return project.projectAccentColor.opacity(0.40)
        }

        if isActive {
            return project.projectAccentColor
        }

        return project.projectAccentColor.opacity(0.82)
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

            HStack(spacing: 8) {
                Circle()
                    .fill(project.projectAccentColor)
                    .frame(width: 10, height: 10)

                Text(project.displayName)
                    .font(.headline)
            }

            Text(project.displayClientName)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let task {
                Text(task.displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(project.projectAccentColor)
            } else {
                Text("Ohne Aufgabe")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                Text(TimeFormatting.digitalDuration(session.duration(referenceDate: timeline.date)))
                    .font(.title2)
                    .bold()
                    .monospacedDigit()
            }

            Button("Tracking stoppen", action: onStop)
                .buttonStyle(.borderedProminent)
                .tint(ClientProject.stopActionColor)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [project.projectAccentColor.opacity(0.26), project.projectAccentColor.opacity(0.12)],
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
                    .platformWindowBackground,
                    Color.teal.opacity(0.06),
                    Color.orange.opacity(0.05),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                Text("Zeiten pro Kundenprojekt erfassen")
                    .font(.largeTitle)
                    .bold()
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Lege dein erstes Projekt an und starte die Zeiterfassung direkt aus der Uebersicht.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Projekt anlegen", action: onAddProject)
                    .buttonStyle(.borderedProminent)
                    .tint(ClientProject.primaryActionColor)
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
