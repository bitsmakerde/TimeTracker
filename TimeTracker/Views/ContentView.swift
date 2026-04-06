import SwiftData
import SwiftUI
import Charts
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
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
    @State private var selectedWorkspaceSection: WorkspaceSection = .tracking
    @State private var isPresentingNewProjectSheet = false
    @State private var isPresentingManualSessionSheet = false
    @State private var sessionEditor: SessionEditor?
    @State private var initialClientNameForNewProject = ""
    @State private var errorMessage: String?

    private let trackingManager = TrackingManager()

    private var activeSession: WorkSession? {
        activeSessions.first
    }

    private var isCompactLayout: Bool {
        horizontalSizeClass == .compact
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

    @ViewBuilder
    private var workspaceLayout: some View {
#if os(iOS)
        if isCompactLayout {
            TabView(selection: $selectedWorkspaceSection) {
                Tab(
                    "Aufnehmen",
                    systemImage: "record.circle",
                    value: WorkspaceSection.tracking
                ) {
                    navigationLayout(for: .tracking, showsWorkspaceTabBar: false)
                }

                Tab(
                    "Auswertung",
                    systemImage: "chart.bar.xaxis",
                    value: WorkspaceSection.analytics
                ) {
                    navigationLayout(for: .analytics, showsWorkspaceTabBar: false)
                }
            }
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarBackground(.regularMaterial, for: .tabBar)
        } else {
            navigationLayout(
                for: selectedWorkspaceSection,
                showsWorkspaceTabBar: true
            )
        }
#else
        navigationLayout(
            for: selectedWorkspaceSection,
            showsWorkspaceTabBar: true
        )
#endif
    }

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

private enum WorkspaceSection: String, CaseIterable, Identifiable {
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

private struct WorkspaceTabButton: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(minWidth: 160)
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
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
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
                    .font(.system(size: 34, weight: .bold, design: .rounded))

                Text("Lege dein erstes Projekt an und starte die Zeiterfassung direkt aus der Uebersicht.")
                    .font(.title3)
                    .foregroundStyle(.secondary)

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

private struct AnalyticsOverviewView: View {
    @Environment(\.colorScheme) private var colorScheme

    let projects: [ClientProject]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let snapshot = AnalyticsCalculator.makeSnapshot(
                projects: projects,
                referenceDate: timeline.date
            )

            ZStack {
                pageBackgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        AnalyticsHeaderCard(snapshot: snapshot)
                        AnalyticsMetricGrid(snapshot: snapshot)
                        AnalyticsTopProjectsCard(snapshot: snapshot)
                        AnalyticsWeeklyHoursCard(snapshot: snapshot)
                        AnalyticsDailyDistributionCard(snapshot: snapshot)
                    }
                    .padding(28)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private var pageBackgroundGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    .platformWindowBackground,
                    Color.teal.opacity(0.14),
                    Color.black.opacity(0.20),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [
                Color(red: 0.95, green: 0.97, blue: 0.98),
                Color.teal.opacity(0.14),
                Color.white.opacity(0.72),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct AnalyticsHeaderCard: View {
    let snapshot: AnalyticsSnapshot

    var body: some View {
        AnalyticsCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Auswertungen")
                    .font(.system(size: 34, weight: .bold, design: .rounded))

                Text("Top-Projekte, Wochenstunden und taegliche Arbeitsverteilung auf einen Blick.")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text(snapshot.subtitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct AnalyticsMetricGrid: View {
    let snapshot: AnalyticsSnapshot

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 180), spacing: 16),
            ],
            spacing: 16
        ) {
            AnalyticsMetricCard(
                title: "Gesamtzeit",
                value: TimeFormatting.compactDuration(snapshot.totalDuration),
                subtitle: "\(snapshot.sessionCount) Eintraege"
            )

            AnalyticsMetricCard(
                title: "Gesamtwert",
                value: snapshot.totalValueText,
                subtitle: snapshot.totalValueSubtitle
            )

            AnalyticsMetricCard(
                title: "Diese Woche",
                value: TimeFormatting.compactDuration(snapshot.currentWeekDuration),
                subtitle: "Kalenderwoche aktuell"
            )

            AnalyticsMetricCard(
                title: "Heute",
                value: TimeFormatting.compactDuration(snapshot.todayDuration),
                subtitle: "Seit 00:00 Uhr"
            )
        }
    }
}

private struct AnalyticsMetricCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(secondaryTextStyle)

            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(secondaryTextStyle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(cardGradient)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(cardStroke, lineWidth: 1)
        )
        .clipShape(.rect(cornerRadius: 24, style: .continuous))
        .shadow(color: cardShadow, radius: 10, x: 0, y: 6)
    }

    private var secondaryTextStyle: Color {
        colorScheme == .dark ? Color.white.opacity(0.66) : Color.black.opacity(0.60)
    }

    private var cardGradient: LinearGradient {
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

    private var cardStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.10)
    }

    private var cardShadow: Color {
        colorScheme == .dark ? Color.black.opacity(0.12) : Color.black.opacity(0.07)
    }
}

private struct AnalyticsTopProjectsCard: View {
    @State private var visualization: AnalyticsTopProjectsVisualization = .bar

    let snapshot: AnalyticsSnapshot

    private var topProjects: [AnalyticsProjectTotal] {
        Array(snapshot.projectTotals.prefix(6))
    }

    var body: some View {
        AnalyticsCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center) {
                    Text("Top-Projekte und Zeitverteilung")
                        .font(.title2.weight(.semibold))

                    Spacer()

                    Picker("Darstellung", selection: $visualization) {
                        ForEach(AnalyticsTopProjectsVisualization.allCases) { mode in
                            Label(mode.title, systemImage: mode.systemImage)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 290)
                }

                if topProjects.isEmpty {
                    Text("Noch keine erfassten Zeiten. Starte einen Timer oder trage einen Eintrag nach, damit hier die Verteilung erscheint.")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 12)
                } else if visualization == .bar {
                    ForEach(topProjects) { project in
                        AnalyticsProjectShareRow(
                            project: project,
                            totalDuration: snapshot.totalDuration
                        )
                    }
                } else {
                    AnalyticsTopProjectsPieChart(
                        projects: topProjects,
                        totalDuration: snapshot.totalDuration
                    )
                }
            }
        }
    }
}

private enum AnalyticsTopProjectsVisualization: String, CaseIterable, Identifiable {
    case bar
    case pie

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bar:
            return "Balken"
        case .pie:
            return "Kreis"
        }
    }

    var systemImage: String {
        switch self {
        case .bar:
            return "chart.bar.fill"
        case .pie:
            return "chart.pie.fill"
        }
    }
}

private struct AnalyticsTopProjectsPieChart: View {
    let projects: [AnalyticsProjectTotal]
    let totalDuration: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Chart(projects) { project in
                SectorMark(
                    angle: .value("Zeit", project.duration),
                    innerRadius: .ratio(0.58),
                    angularInset: 1
                )
                .foregroundStyle(by: .value("Projekt", project.legendLabel))
            }
            .modifier(
                AnalyticsChartColorScale(
                    domain: projects.map(\.legendLabel),
                    range: projects.map(\.color)
                )
            )
            .chartLegend(.hidden)
            .frame(minHeight: 290)

            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 180), spacing: 12),
                ],
                spacing: 10
            ) {
                ForEach(projects) { project in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(project.color)
                            .frame(width: 9, height: 9)

                        Text(project.projectName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)

                        Spacer(minLength: 6)

                        Text(project.shareText(totalDuration: totalDuration))
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                    }
                }
            }
        }
    }
}

private struct AnalyticsProjectShareRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let project: AnalyticsProjectTotal
    let totalDuration: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Circle()
                    .fill(project.color)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.projectName)
                        .font(.headline)

                    Text(project.clientName)
                        .font(.caption)
                        .foregroundStyle(secondaryTextStyle)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(TimeFormatting.compactDuration(project.duration))
                        .font(.headline)
                        .monospacedDigit()

                    Text(project.shareText(totalDuration: totalDuration))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(secondaryTextStyle)
                }
            }

            ProgressView(value: project.duration, total: max(totalDuration, 1))
                .tint(project.color)

            Text(project.valueText)
                .font(.caption)
                .foregroundStyle(secondaryTextStyle)
        }
        .padding(12)
        .background(rowBackgroundStyle)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(rowStrokeStyle, lineWidth: 1)
        )
        .clipShape(.rect(cornerRadius: 16, style: .continuous))
    }

    private var secondaryTextStyle: Color {
        colorScheme == .dark ? Color.white.opacity(0.66) : Color.black.opacity(0.62)
    }

    private var rowBackgroundStyle: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.88)
    }

    private var rowStrokeStyle: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.09)
    }
}

private struct AnalyticsWeeklyHoursCard: View {
    let snapshot: AnalyticsSnapshot

    var body: some View {
        AnalyticsCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Wochenstunden nach Projekten")
                    .font(.title2.weight(.semibold))

                Text(snapshot.weeklyRangeLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if snapshot.hasData {
                    Chart(snapshot.weeklyPoints) { point in
                        BarMark(
                            x: .value("Woche", point.periodLabel),
                            y: .value("Stunden", point.hours)
                        )
                        .foregroundStyle(by: .value("Projekt", point.legendLabel))
                    }
                    .modifier(
                        AnalyticsChartColorScale(
                            domain: snapshot.legendLabels,
                            range: snapshot.legendColors
                        )
                    )
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .frame(minHeight: 260)
                } else {
                    Text("Noch keine Daten fuer die Wochenauswertung vorhanden.")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 12)
                }
            }
        }
    }
}

private struct AnalyticsDailyDistributionCard: View {
    let snapshot: AnalyticsSnapshot

    var body: some View {
        AnalyticsCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Tagesprofil 0-24 Uhr")
                    .font(.title2.weight(.semibold))

                Text(snapshot.hourlyRangeLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if snapshot.hasHourlyData {
                    Text(snapshot.peakHourSummary)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Chart(snapshot.hourlyPoints) { point in
                        BarMark(
                            x: .value("Stunde", point.hour),
                            y: .value("Durchschnittliche Stunden", point.averageHours)
                        )
                        .foregroundStyle(by: .value("Projekt", point.legendLabel))
                    }
                    .modifier(
                        AnalyticsChartColorScale(
                            domain: snapshot.legendLabels,
                            range: snapshot.legendColors
                        )
                    )
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .chartXAxis {
                        AxisMarks(values: Array(stride(from: 0, through: 24, by: 2))) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel {
                                if let hour = value.as(Int.self) {
                                    Text("\(hour)")
                                }
                            }
                        }
                    }
                    .frame(minHeight: 260)
                } else {
                    Text("Noch keine Daten fuer das Aktivitaetsprofil vorhanden.")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 12)
                }
            }
        }
    }
}

private struct AnalyticsChartColorScale: ViewModifier {
    let domain: [String]
    let range: [Color]

    @ViewBuilder
    func body(content: Content) -> some View {
        if domain.isEmpty || range.isEmpty {
            content
        } else {
            content.chartForegroundStyleScale(domain: domain, range: range)
        }
    }
}

private struct AnalyticsCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardGradient)
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(cardStroke, lineWidth: 1)
            )
            .clipShape(.rect(cornerRadius: 26, style: .continuous))
            .shadow(color: cardShadow, radius: 14, x: 0, y: 8)
    }

    private var cardGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [Color.white.opacity(0.07), Color.black.opacity(0.20)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [Color.white.opacity(0.98), Color(red: 0.95, green: 0.97, blue: 0.99)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var cardStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.10)
    }

    private var cardShadow: Color {
        colorScheme == .dark ? Color.black.opacity(0.14) : Color.black.opacity(0.08)
    }
}

private struct AnalyticsSnapshot {
    let projectTotals: [AnalyticsProjectTotal]
    let weeklyPoints: [AnalyticsStackedPoint]
    let dailyPoints: [AnalyticsStackedPoint]
    let hourlyPoints: [AnalyticsHourlyPoint]
    let totalDuration: TimeInterval
    let totalBilledAmount: Double
    let hasAnyHourlyRate: Bool
    let sessionCount: Int
    let trackedProjectCount: Int
    let currentWeekDuration: TimeInterval
    let todayDuration: TimeInterval
    let weeklyRangeLabel: String
    let dailyRangeLabel: String
    let hourlyRangeLabel: String
    let peakHourSummary: String

    var hasData: Bool {
        totalDuration > 0
    }

    var hasHourlyData: Bool {
        hourlyPoints.contains(where: { $0.averageDuration > 0 })
    }

    var subtitle: String {
        if hasData {
            return "\(trackedProjectCount) Projekte mit Zeiten aus \(sessionCount) Eintraegen."
        }

        return "Noch keine erfassten Zeiten vorhanden."
    }

    var totalValueText: String {
        if !hasAnyHourlyRate {
            return "Offen"
        }

        return TimeFormatting.euroAmount(totalBilledAmount)
    }

    var totalValueSubtitle: String {
        hasAnyHourlyRate ? "Aus Zeit und Stundensatz" : "Keine Stundensaetze hinterlegt"
    }

    var legendLabels: [String] {
        projectTotals.map(\.legendLabel)
    }

    var legendColors: [Color] {
        projectTotals.map(\.color)
    }
}

private struct AnalyticsProjectTotal: Identifiable {
    let id: UUID
    let projectName: String
    let clientName: String
    let legendLabel: String
    let color: Color
    let duration: TimeInterval
    let billedAmount: Double
    let hasHourlyRate: Bool

    var valueText: String {
        if !hasHourlyRate {
            return "Kein Stundensatz"
        }

        return TimeFormatting.euroAmount(billedAmount)
    }

    func shareText(totalDuration: TimeInterval) -> String {
        let safeTotal = max(totalDuration, 1)
        let share = duration / safeTotal
        return share.formatted(.percent.precision(.fractionLength(0)))
    }
}

private struct AnalyticsStackedPoint: Identifiable {
    let periodStart: Date
    let periodLabel: String
    let projectID: UUID
    let legendLabel: String
    let color: Color
    let duration: TimeInterval

    var id: String {
        "\(periodLabel)-\(projectID.uuidString)"
    }

    var hours: Double {
        duration / 3600
    }
}

private struct AnalyticsHourlyPoint: Identifiable {
    let hour: Int
    let projectID: UUID
    let legendLabel: String
    let color: Color
    let averageDuration: TimeInterval

    var id: String {
        "\(hour)-\(projectID.uuidString)"
    }

    var averageHours: Double {
        averageDuration / 3600
    }
}

private struct AnalyticsProjectMetadata {
    let id: UUID
    let projectName: String
    let clientName: String
    let legendLabel: String
    let color: Color
    let hourlyRate: Double?
}

private enum AnalyticsCalculator {
    private static let weeklyWindowCount = 8
    private static let dailyWindowCount = 14

    static func makeSnapshot(
        projects: [ClientProject],
        referenceDate: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> AnalyticsSnapshot {
        let metadata = buildProjectMetadata(projects: projects)
        let dayDurations = buildDayDurations(
            projects: projects,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let projectTotals = buildProjectTotals(
            dayDurations: dayDurations,
            metadata: metadata
        )
        let weeklyComputation = buildWeeklyPoints(
            dayDurations: dayDurations,
            projectTotals: projectTotals,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let dailyComputation = buildDailyPoints(
            dayDurations: dayDurations,
            projectTotals: projectTotals,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let hourlyComputation = buildHourlyPoints(
            projects: projects,
            projectTotals: projectTotals,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let totalDuration = projectTotals.reduce(0) { partialResult, project in
            partialResult + project.duration
        }
        let totalBilledAmount = projectTotals.reduce(0) { partialResult, project in
            partialResult + project.billedAmount
        }
        let hasAnyHourlyRate = projectTotals.contains(where: { $0.hasHourlyRate })
        let todayDuration = totalDurationForToday(
            dayDurations: dayDurations,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let currentWeekDuration = totalDurationForCurrentWeek(
            dayDurations: dayDurations,
            referenceDate: referenceDate,
            calendar: calendar
        )

        return AnalyticsSnapshot(
            projectTotals: projectTotals,
            weeklyPoints: weeklyComputation.points,
            dailyPoints: dailyComputation.points,
            hourlyPoints: hourlyComputation.points,
            totalDuration: totalDuration,
            totalBilledAmount: totalBilledAmount,
            hasAnyHourlyRate: hasAnyHourlyRate,
            sessionCount: projects.reduce(into: 0) { partialResult, project in
                partialResult += project.sessions.count
            },
            trackedProjectCount: projectTotals.count,
            currentWeekDuration: currentWeekDuration,
            todayDuration: todayDuration,
            weeklyRangeLabel: weeklyComputation.rangeLabel,
            dailyRangeLabel: dailyComputation.rangeLabel,
            hourlyRangeLabel: hourlyComputation.rangeLabel,
            peakHourSummary: hourlyComputation.peakSummary
        )
    }

    private static func buildProjectMetadata(
        projects: [ClientProject]
    ) -> [UUID: AnalyticsProjectMetadata] {
        Dictionary(
            uniqueKeysWithValues: projects.map { project in
                let legendLabel = "\(project.displayName) (\(project.displayClientName))"
                return (
                    project.id,
                    AnalyticsProjectMetadata(
                        id: project.id,
                        projectName: project.displayName,
                        clientName: project.displayClientName,
                        legendLabel: legendLabel,
                        color: project.projectAccentColor,
                        hourlyRate: project.hourlyRate
                    )
                )
            }
        )
    }

    private static func buildDayDurations(
        projects: [ClientProject],
        referenceDate: Date,
        calendar: Calendar
    ) -> [Date: [UUID: TimeInterval]] {
        var dayDurations: [Date: [UUID: TimeInterval]] = [:]

        for project in projects {
            for session in project.sessions {
                let sessionEnd = session.endedAt ?? referenceDate
                guard sessionEnd > session.startedAt else {
                    continue
                }

                var cursor = session.startedAt

                while cursor < sessionEnd {
                    let dayStart = calendar.startOfDay(for: cursor)
                    guard let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart),
                          nextDayStart > cursor else {
                        break
                    }

                    let segmentEnd = min(nextDayStart, sessionEnd)
                    let overlapDuration = segmentEnd.timeIntervalSince(cursor)

                    if overlapDuration > 0 {
                        var projectDurations = dayDurations[dayStart] ?? [:]
                        projectDurations[project.id, default: 0] += overlapDuration
                        dayDurations[dayStart] = projectDurations
                    }

                    cursor = segmentEnd
                }
            }
        }

        return dayDurations
    }

    private static func buildProjectTotals(
        dayDurations: [Date: [UUID: TimeInterval]],
        metadata: [UUID: AnalyticsProjectMetadata]
    ) -> [AnalyticsProjectTotal] {
        var durationByProject: [UUID: TimeInterval] = [:]

        for projectDurations in dayDurations.values {
            for (projectID, duration) in projectDurations {
                durationByProject[projectID, default: 0] += duration
            }
        }

        return durationByProject.compactMap { projectID, duration in
            guard duration > 0,
                  let projectMetadata = metadata[projectID] else {
                return nil
            }

            let hasHourlyRate = projectMetadata.hourlyRate != nil
            let hourlyRate = max(projectMetadata.hourlyRate ?? 0, 0)
            let billedAmount = hasHourlyRate ? (duration / 3600) * hourlyRate : 0

            return AnalyticsProjectTotal(
                id: projectID,
                projectName: projectMetadata.projectName,
                clientName: projectMetadata.clientName,
                legendLabel: projectMetadata.legendLabel,
                color: projectMetadata.color,
                duration: duration,
                billedAmount: billedAmount,
                hasHourlyRate: hasHourlyRate
            )
        }
        .sorted { lhs, rhs in
            if lhs.duration == rhs.duration {
                return lhs.projectName.localizedCaseInsensitiveCompare(rhs.projectName) == .orderedAscending
            }

            return lhs.duration > rhs.duration
        }
    }

    private static func buildWeeklyPoints(
        dayDurations: [Date: [UUID: TimeInterval]],
        projectTotals: [AnalyticsProjectTotal],
        referenceDate: Date,
        calendar: Calendar
    ) -> AnalyticsPeriodComputation {
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start
            ?? calendar.startOfDay(for: referenceDate)
        let oldestWeekStart = calendar.date(byAdding: .weekOfYear, value: -(weeklyWindowCount - 1), to: currentWeekStart)
            ?? currentWeekStart
        let weekStarts = makePeriodStarts(
            from: oldestWeekStart,
            count: weeklyWindowCount,
            component: .weekOfYear,
            calendar: calendar
        )
        let endDate = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart) ?? referenceDate
        var durationsByWeek: [Date: [UUID: TimeInterval]] = [:]

        for (dayStart, projectDurations) in dayDurations {
            guard dayStart >= oldestWeekStart, dayStart < endDate else {
                continue
            }

            let weekStart = calendar.dateInterval(of: .weekOfYear, for: dayStart)?.start ?? dayStart
            var weekBucket = durationsByWeek[weekStart] ?? [:]

            for (projectID, duration) in projectDurations {
                weekBucket[projectID, default: 0] += duration
            }

            durationsByWeek[weekStart] = weekBucket
        }

        let points = makeStackedPoints(
            periodStarts: weekStarts,
            durationsByPeriod: durationsByWeek,
            projectTotals: projectTotals,
            periodLabel: { weekStart in
                weekLabel(weekStart: weekStart, calendar: calendar)
            }
        )
        let rangeLabel = makeRangeLabel(
            periodStarts: weekStarts,
            periodComponent: .weekOfYear,
            calendar: calendar
        )

        return AnalyticsPeriodComputation(points: points, rangeLabel: rangeLabel)
    }

    private static func buildDailyPoints(
        dayDurations: [Date: [UUID: TimeInterval]],
        projectTotals: [AnalyticsProjectTotal],
        referenceDate: Date,
        calendar: Calendar
    ) -> AnalyticsPeriodComputation {
        let currentDayStart = calendar.startOfDay(for: referenceDate)
        let oldestDayStart = calendar.date(byAdding: .day, value: -(dailyWindowCount - 1), to: currentDayStart)
            ?? currentDayStart
        let dayStarts = makePeriodStarts(
            from: oldestDayStart,
            count: dailyWindowCount,
            component: .day,
            calendar: calendar
        )
        let endDate = calendar.date(byAdding: .day, value: 1, to: currentDayStart) ?? referenceDate
        var durationsByDay: [Date: [UUID: TimeInterval]] = [:]

        for (dayStart, projectDurations) in dayDurations {
            guard dayStart >= oldestDayStart, dayStart < endDate else {
                continue
            }

            durationsByDay[dayStart] = projectDurations
        }

        let points = makeStackedPoints(
            periodStarts: dayStarts,
            durationsByPeriod: durationsByDay,
            projectTotals: projectTotals,
            periodLabel: { dayStart in
                dayStart.formatted(
                    .dateTime
                        .day()
                        .month(.abbreviated)
                )
            }
        )
        let rangeLabel = makeRangeLabel(
            periodStarts: dayStarts,
            periodComponent: .day,
            calendar: calendar
        )

        return AnalyticsPeriodComputation(points: points, rangeLabel: rangeLabel)
    }

    private static func buildHourlyPoints(
        projects: [ClientProject],
        projectTotals: [AnalyticsProjectTotal],
        referenceDate: Date,
        calendar: Calendar
    ) -> AnalyticsHourlyComputation {
        let currentDayStart = calendar.startOfDay(for: referenceDate)
        let oldestDayStart = calendar.date(byAdding: .day, value: -(dailyWindowCount - 1), to: currentDayStart)
            ?? currentDayStart
        let rangeEnd = calendar.date(byAdding: .day, value: 1, to: currentDayStart)
            ?? referenceDate
        let averageDivisor = Double(dailyWindowCount)
        let totalsByProjectID = Dictionary(uniqueKeysWithValues: projectTotals.map { ($0.id, $0) })
        let fallbackProject = projectTotals.first
        var durationsByHour: [Int: [UUID: TimeInterval]] = [:]

        for project in projects {
            for session in project.sessions {
                let sessionEnd = session.endedAt ?? referenceDate
                let effectiveStart = max(session.startedAt, oldestDayStart)
                let effectiveEnd = min(sessionEnd, rangeEnd)

                guard effectiveEnd > effectiveStart else {
                    continue
                }

                var cursor = effectiveStart

                while cursor < effectiveEnd {
                    guard let hourInterval = calendar.dateInterval(of: .hour, for: cursor) else {
                        break
                    }

                    let overlapEnd = min(hourInterval.end, effectiveEnd)
                    let overlapDuration = overlapEnd.timeIntervalSince(cursor)

                    if overlapDuration > 0 {
                        let hour = calendar.component(.hour, from: hourInterval.start)
                        var projectDurations = durationsByHour[hour] ?? [:]
                        projectDurations[project.id, default: 0] += overlapDuration / averageDivisor
                        durationsByHour[hour] = projectDurations
                    }

                    cursor = overlapEnd
                }
            }
        }

        var points: [AnalyticsHourlyPoint] = []
        var peakHour: Int?
        var peakAverageDuration: TimeInterval = 0

        for hour in 0..<24 {
            let projectDurations = durationsByHour[hour] ?? [:]
            let totalAverageDuration = projectDurations.values.reduce(0, +)

            if totalAverageDuration > peakAverageDuration {
                peakAverageDuration = totalAverageDuration
                peakHour = hour
            }

            if projectDurations.isEmpty, let fallbackProject {
                points.append(
                    AnalyticsHourlyPoint(
                        hour: hour,
                        projectID: fallbackProject.id,
                        legendLabel: fallbackProject.legendLabel,
                        color: fallbackProject.color,
                        averageDuration: 0
                    )
                )
                continue
            }

            let sortedProjectIDs = projectDurations.keys.sorted { lhs, rhs in
                let leftDuration = projectDurations[lhs] ?? 0
                let rightDuration = projectDurations[rhs] ?? 0

                if leftDuration == rightDuration {
                    let leftName = totalsByProjectID[lhs]?.projectName ?? ""
                    let rightName = totalsByProjectID[rhs]?.projectName ?? ""
                    return leftName.localizedCaseInsensitiveCompare(rightName) == .orderedAscending
                }

                return leftDuration > rightDuration
            }

            for projectID in sortedProjectIDs {
                guard let project = totalsByProjectID[projectID] else {
                    continue
                }

                points.append(
                    AnalyticsHourlyPoint(
                        hour: hour,
                        projectID: projectID,
                        legendLabel: project.legendLabel,
                        color: project.color,
                        averageDuration: projectDurations[projectID] ?? 0
                    )
                )
            }
        }

        let rangeLabel = "\(oldestDayStart.formatted(date: .abbreviated, time: .omitted)) - \(currentDayStart.formatted(date: .abbreviated, time: .omitted))"
        let peakSummary = makePeakHourSummary(peakHour: peakHour, peakAverageDuration: peakAverageDuration)

        return AnalyticsHourlyComputation(
            points: points,
            rangeLabel: rangeLabel,
            peakSummary: peakSummary
        )
    }

    private static func makeStackedPoints(
        periodStarts: [Date],
        durationsByPeriod: [Date: [UUID: TimeInterval]],
        projectTotals: [AnalyticsProjectTotal],
        periodLabel: (Date) -> String
    ) -> [AnalyticsStackedPoint] {
        let totalsByProjectID = Dictionary(uniqueKeysWithValues: projectTotals.map { ($0.id, $0) })
        let fallbackProject = projectTotals.first
        var points: [AnalyticsStackedPoint] = []

        for periodStart in periodStarts {
            let projectDurations = durationsByPeriod[periodStart] ?? [:]

            if projectDurations.isEmpty, let fallbackProject {
                points.append(
                    AnalyticsStackedPoint(
                        periodStart: periodStart,
                        periodLabel: periodLabel(periodStart),
                        projectID: fallbackProject.id,
                        legendLabel: fallbackProject.legendLabel,
                        color: fallbackProject.color,
                        duration: 0
                    )
                )
                continue
            }

            let sortedProjectIDs = projectDurations.keys.sorted { lhs, rhs in
                let leftDuration = projectDurations[lhs] ?? 0
                let rightDuration = projectDurations[rhs] ?? 0

                if leftDuration == rightDuration {
                    let leftName = totalsByProjectID[lhs]?.projectName ?? ""
                    let rightName = totalsByProjectID[rhs]?.projectName ?? ""
                    return leftName.localizedCaseInsensitiveCompare(rightName) == .orderedAscending
                }

                return leftDuration > rightDuration
            }

            for projectID in sortedProjectIDs {
                guard let projectTotal = totalsByProjectID[projectID] else {
                    continue
                }

                points.append(
                    AnalyticsStackedPoint(
                        periodStart: periodStart,
                        periodLabel: periodLabel(periodStart),
                        projectID: projectID,
                        legendLabel: projectTotal.legendLabel,
                        color: projectTotal.color,
                        duration: projectDurations[projectID] ?? 0
                    )
                )
            }
        }

        return points
    }

    private static func makePeriodStarts(
        from startDate: Date,
        count: Int,
        component: Calendar.Component,
        calendar: Calendar
    ) -> [Date] {
        (0..<count).compactMap { offset in
            calendar.date(byAdding: component, value: offset, to: startDate)
        }
    }

    private static func weekLabel(
        weekStart: Date,
        calendar: Calendar
    ) -> String {
        let weekNumber = calendar.component(.weekOfYear, from: weekStart)
        let year = calendar.component(.yearForWeekOfYear, from: weekStart) % 100
        return "KW \(weekNumber)/\(year)"
    }

    private static func makeRangeLabel(
        periodStarts: [Date],
        periodComponent: Calendar.Component,
        calendar: Calendar
    ) -> String {
        guard let firstStart = periodStarts.first,
              let lastStart = periodStarts.last else {
            return ""
        }

        let visibleEndDate: Date
        switch periodComponent {
        case .weekOfYear:
            visibleEndDate = calendar.date(byAdding: .day, value: 6, to: lastStart) ?? lastStart
        default:
            visibleEndDate = lastStart
        }

        return "\(firstStart.formatted(date: .abbreviated, time: .omitted)) - \(visibleEndDate.formatted(date: .abbreviated, time: .omitted))"
    }

    private static func totalDurationForToday(
        dayDurations: [Date: [UUID: TimeInterval]],
        referenceDate: Date,
        calendar: Calendar
    ) -> TimeInterval {
        let todayStart = calendar.startOfDay(for: referenceDate)
        return dayDurations[todayStart]?.values.reduce(0, +) ?? 0
    }

    private static func totalDurationForCurrentWeek(
        dayDurations: [Date: [UUID: TimeInterval]],
        referenceDate: Date,
        calendar: Calendar
    ) -> TimeInterval {
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start
            ?? calendar.startOfDay(for: referenceDate)
        let currentWeekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart)
            ?? referenceDate

        return dayDurations.reduce(into: 0) { partialResult, entry in
            let dayStart = entry.key
            guard dayStart >= currentWeekStart, dayStart < currentWeekEnd else {
                return
            }

            partialResult += entry.value.values.reduce(0, +)
        }
    }

    private static func makePeakHourSummary(
        peakHour: Int?,
        peakAverageDuration: TimeInterval
    ) -> String {
        guard let peakHour, peakAverageDuration > 0 else {
            return "Noch keine Aktivitaet im betrachteten Zeitraum."
        }

        let nextHour = (peakHour + 1) % 24
        let peakHourText = peakHour.formatted(.number.precision(.integerLength(2)))
        let nextHourText = nextHour.formatted(.number.precision(.integerLength(2)))

        return "Aktivstes Zeitfenster: \(peakHourText):00-\(nextHourText):00 mit durchschnittlich \(TimeFormatting.compactDuration(peakAverageDuration)) pro Tag."
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

private struct AnalyticsPeriodComputation {
    let points: [AnalyticsStackedPoint]
    let rangeLabel: String
}

private struct AnalyticsHourlyComputation {
    let points: [AnalyticsHourlyPoint]
    let rangeLabel: String
    let peakSummary: String
}
