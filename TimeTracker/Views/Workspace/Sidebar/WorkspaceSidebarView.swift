import SwiftData
import SwiftUI

struct WorkspaceSidebarView: View {
    @Bindable var viewModel: WorkspaceRootViewModel
    let projects: [ClientProject]
    let activeSessions: [WorkSession]
    let dependencies: AppDependencies
    let modelContext: ModelContext
    let trackingStatus: TrackingStatusStore

    var body: some View {
        let activeSession = viewModel.activeSession(from: activeSessions)
        let groupedProjects = viewModel.groupedProjects(from: projects)
        let archivedProjects = viewModel.archivedProjects(from: projects)

        List(selection: $viewModel.selectedProjectID) {
            activeSessionSection(activeSession)
            projectSections(groupedProjects, activeSession: activeSession)
            archiveSection(archivedProjects)
        }
        .navigationTitle("Zeittracker")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    viewModel.presentNewProjectSheet()
                } label: {
                    Label("Projekt", systemImage: "plus")
                }

                if activeSession != nil {
                    Button(role: .destructive, action: stopActiveTracking) {
                        Label("Stopp", systemImage: "stop.fill")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func activeSessionSection(_ activeSession: WorkSession?) -> some View {
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
    }

    private func projectSections(
        _ groupedProjects: [ClientGroup],
        activeSession: WorkSession?
    ) -> some View {
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
                        viewModel.presentNewProjectSheet(for: group.rawClientName)
                    }
                )
            }
        }
    }

    @ViewBuilder
    private func archiveSection(_ archivedProjects: [ClientProject]) -> some View {
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

    private func stopActiveTracking() {
        viewModel.stopActiveTracking(
            dependencies: dependencies,
            modelContext: modelContext,
            trackingStatus: trackingStatus
        )
    }
}

#Preview("Workspace sidebar") {
    NavigationSplitView {
        WorkspaceSidebarPreviewHost()
            .navigationSplitViewColumnWidth(min: 340, ideal: 360, max: 420)
    } detail: {
        Text("Detail")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(width: 980, height: 720)
}

private struct WorkspaceSidebarPreviewHost: View {
    private let modelContainer: ModelContainer
    private let projects: [ClientProject]
    private let activeSessions: [WorkSession]
    private let trackingStatus: TrackingStatusStore
    @State private var viewModel = WorkspaceRootViewModel()

    init() {
        let modelContainer = Self.makeModelContainer()
        let activeProject = ClientProject(
            clientName: "Acme Corp",
            name: "Website Redesign",
            hourlyRate: 85,
            accentRed: 0.0,
            accentGreen: 0.48,
            accentBlue: 1.0
        )
        let appProject = ClientProject(
            clientName: "Northwind",
            name: "iOS App",
            hourlyRate: 110,
            accentRed: 0.20,
            accentGreen: 0.78,
            accentBlue: 0.35
        )
        let archivedProject = ClientProject(
            clientName: "Archiv GmbH",
            name: "Relaunch 2024",
            archivedAt: .now.addingTimeInterval(-86_400),
            accentRed: 1.0,
            accentGreen: 0.58,
            accentBlue: 0.0
        )
        let task = ProjectTask(title: "Landing Page", project: activeProject)
        let activeSession = WorkSession(
            project: activeProject,
            task: task,
            startedAt: .now.addingTimeInterval(-3_600)
        )
        activeProject.tasks = [task]
        activeProject.sessions = [activeSession]

        self.modelContainer = modelContainer
        self.projects = [activeProject, appProject, archivedProject]
        self.activeSessions = [activeSession]
        self.trackingStatus = TrackingStatusStore(
            modelContainer: modelContainer,
            crossDeviceChannel: NoopCrossDeviceTrackingChannel()
        )
    }

    var body: some View {
        WorkspaceSidebarView(
            viewModel: viewModel,
            projects: projects,
            activeSessions: activeSessions,
            dependencies: .live(configuration: TimeTrackerTargetConfiguration.macOS),
            modelContext: modelContainer.mainContext,
            trackingStatus: trackingStatus
        )
        .modelContainer(modelContainer)
        .onAppear {
            viewModel.ensureInitialSelection(projects: projects)
        }
    }

    private static func makeModelContainer() -> ModelContainer {
        do {
            return try TimeTrackerSchema.makeModelContainer(isStoredInMemoryOnly: true)
        } catch {
            fatalError("WorkspaceSidebarView preview model container could not be created: \(error)")
        }
    }
}
