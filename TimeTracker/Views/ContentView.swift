import SwiftData
import SwiftUI

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
        sort: [SortDescriptor(\WorkSession.startedAt, order: .forward)]
    )
    private var activeSessions: [WorkSession]

    @State private var viewModel = WorkspaceRootViewModel()

    var body: some View {
        @Bindable var viewModel = viewModel

        workspaceLayout
            .sheet(isPresented: $viewModel.isPresentingNewProjectSheet, content: newProjectSheet)
            .sheet(isPresented: $viewModel.isPresentingManualSessionSheet, content: manualSessionSheet)
            .sheet(item: $viewModel.sessionEditor, content: sessionEditorSheet(editor:))
            .alert(
                "Aktion fehlgeschlagen",
                isPresented: $viewModel.isPresentingError,
                actions: alertActions,
                message: alertMessage
            )
            .onAppear {
                viewModel.ensureInitialSelection(projects: projects)
            }
            .onChange(of: viewModel.projectIDList(from: projects)) { _, projectIDs in
                viewModel.synchronizeSelection(with: projectIDs)
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
        let activeSection = viewModel.activeWorkspaceSection(forcedWorkspaceSection: forcedWorkspaceSection)
        let showsTabBar = showsWorkspaceSectionPicker && forcedWorkspaceSection == nil

#if os(iOS)
        if WorkspaceRootLayoutRules.usesTabRoot(
            horizontalSizeClass: horizontalSizeClass,
            forcedWorkspaceSection: forcedWorkspaceSection,
            prefersNativeTabBar: dependencies.configuration.featureFlags.usesNativeCompactTabBar
        ) {
            WorkspaceCompactTabRootView(
                viewModel: viewModel,
                projects: projects,
                activeSessions: activeSessions,
                dependencies: dependencies,
                modelContext: modelContext,
                trackingStatus: trackingStatus
            )
        } else if horizontalSizeClass == .compact {
            NavigationStack {
                detailArea(for: activeSection, showsWorkspaceTabBar: false)
                    .navigationTitle(activeSection.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        if activeSection == .tracking {
                            WorkspaceCompactTrackingToolbar(
                                viewModel: viewModel,
                                activeProjects: viewModel.activeProjects(from: projects),
                                hasActiveSession: viewModel.activeSession(from: activeSessions) != nil,
                                dependencies: dependencies,
                                modelContext: modelContext,
                                trackingStatus: trackingStatus
                            )
                        }
                    }
            }
        } else {
            navigationLayout(for: activeSection, showsWorkspaceTabBar: showsTabBar)
        }
#else
        navigationLayout(for: activeSection, showsWorkspaceTabBar: showsTabBar)
#endif
    }

    private func navigationLayout(
        for section: WorkspaceSection,
        showsWorkspaceTabBar: Bool
    ) -> some View {
        NavigationSplitView {
            WorkspaceSidebarView(
                viewModel: viewModel,
                projects: projects,
                activeSessions: activeSessions,
                dependencies: dependencies,
                modelContext: modelContext,
                trackingStatus: trackingStatus
            )
        } detail: {
            detailArea(
                for: section,
                showsWorkspaceTabBar: showsWorkspaceTabBar
            )
        }
        .navigationSplitViewStyle(.balanced)
    }

    private func detailArea(
        for section: WorkspaceSection,
        showsWorkspaceTabBar: Bool
    ) -> some View {
        WorkspaceDetailAreaView(
            viewModel: viewModel,
            section: section,
            showsWorkspaceTabBar: showsWorkspaceTabBar,
            projects: projects,
            activeSessions: activeSessions,
            dependencies: dependencies,
            modelContext: modelContext,
            trackingStatus: trackingStatus
        )
    }

    private func newProjectSheet() -> some View {
        NewProjectSheet(initialClientName: viewModel.initialClientNameForNewProject) { project in
            viewModel.saveNewProject(project, in: modelContext)
        }
    }

    @ViewBuilder
    private func manualSessionSheet() -> some View {
        if let selectedProject = viewModel.selectedProject(in: projects) {
            ManualSessionSheet(project: selectedProject) { startedAt, endedAt, task in
                viewModel.addManualSession(
                    for: selectedProject,
                    task: task,
                    startedAt: startedAt,
                    endedAt: endedAt,
                    dependencies: dependencies,
                    modelContext: modelContext
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
            viewModel.updateManualSession(
                editor.session,
                task: task,
                startedAt: startedAt,
                endedAt: endedAt,
                dependencies: dependencies,
                modelContext: modelContext
            )
        }
    }

    private func alertActions() -> some View {
        Button("OK", role: .cancel) {}
    }

    private func alertMessage() -> some View {
        Text(viewModel.errorMessage ?? "")
    }
}
