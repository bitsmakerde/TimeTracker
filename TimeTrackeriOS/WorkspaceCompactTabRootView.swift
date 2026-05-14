
import SwiftData
import SwiftUI

struct WorkspaceCompactTabRootView: View {
    @Bindable var viewModel: WorkspaceRootViewModel
    let projects: [ClientProject]
    let activeSessions: [WorkSession]
    let dependencies: AppDependencies
    let modelContext: ModelContext
    let trackingStatus: TrackingStatusStore

    var body: some View {
        TabView(selection: $viewModel.selectedWorkspaceSection) {
            Tab(
                WorkspaceSection.tracking.title,
                systemImage: WorkspaceSection.tracking.systemImage,
                value: WorkspaceSection.tracking
            ) {
                NavigationStack {
                    WorkspaceTrackingDetailView(
                        viewModel: viewModel,
                        projects: projects,
                        activeSessions: activeSessions,
                        dependencies: dependencies,
                        modelContext: modelContext,
                        trackingStatus: trackingStatus
                    )
                    .navigationTitle(WorkspaceSection.tracking.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
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
}

#Preview {
    WorkspaceCompactTabRootPreviewHost()
}

private struct WorkspaceCompactTabRootPreviewHost: View {
    private let modelContainer: ModelContainer
    private let projects: [ClientProject]
    private let activeSessions: [WorkSession]
    private let trackingStatus: TrackingStatusStore
    @State private var viewModel = WorkspaceRootViewModel()

    init() {
        let modelContainer = Self.makeModelContainer()
        let projects = ClientProject.sampleData

        self.modelContainer = modelContainer
        self.projects = projects
        self.activeSessions = WorkSession.sampleActiveData(for: projects)
        self.trackingStatus = TrackingStatusStore.preview(modelContainer: modelContainer)
    }

    var body: some View {
        WorkspaceCompactTabRootView(
            viewModel: viewModel,
            projects: projects,
            activeSessions: activeSessions,
            dependencies: .preview,
            modelContext: modelContainer.mainContext,
            trackingStatus: trackingStatus
        )
        .modelContainer(modelContainer)
    }

    private static func makeModelContainer() -> ModelContainer {
        do {
            return try TimeTrackerSchema.makeModelContainer(isStoredInMemoryOnly: true)
        } catch {
            fatalError("WorkspaceCompactTabRootView preview model container could not be created: \(error)")
        }
    }
}
