import SwiftData
import SwiftUI

struct WorkspaceDetailAreaView: View {
    @Bindable var viewModel: WorkspaceRootViewModel
    let section: WorkspaceSection
    let showsWorkspaceTabBar: Bool
    let projects: [ClientProject]
    let activeSessions: [WorkSession]
    let dependencies: AppDependencies
    let modelContext: ModelContext
    let trackingStatus: TrackingStatusStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsWorkspaceTabBar {
                WorkspaceTabBarView(
                    selectedSection: viewModel.selectedWorkspaceSection,
                    onSelectSection: { section in
                        viewModel.selectedWorkspaceSection = section
                    }
                )
            }

            if section == .analytics {
                AnalyticsOverviewView(projects: projects)
            } else {
                WorkspaceTrackingDetailView(
                    viewModel: viewModel,
                    projects: projects,
                    activeSessions: activeSessions,
                    dependencies: dependencies,
                    modelContext: modelContext,
                    trackingStatus: trackingStatus
                )
            }
        }
    }
}

#Preview("Workspace detail") {
    WorkspaceDetailAreaPreviewHost()
}

private struct WorkspaceDetailAreaPreviewHost: View {
    private let modelContainer: ModelContainer
    private let project: ClientProject
    private let trackingStatus: TrackingStatusStore
    @State private var viewModel = WorkspaceRootViewModel()

    init() {
        let modelContainer = Self.makeModelContainer()
        let project = ClientProject(
            clientName: "Acme Corp",
            name: "Website Redesign",
            hourlyRate: 85,
            budgetUnitRaw: ProjectBudgetUnit.hours.rawValue,
            budgetTarget: 20,
            accentRed: 0.0,
            accentGreen: 0.48,
            accentBlue: 1.0
        )
        let task = ProjectTask(title: "Landing Page", project: project)
        project.tasks = [task]
        project.sessions = [
            WorkSession(
                project: project,
                task: task,
                startedAt: .now.addingTimeInterval(-7_200),
                endedAt: .now.addingTimeInterval(-3_600)
            ),
        ]

        self.modelContainer = modelContainer
        self.project = project
        self.trackingStatus = TrackingStatusStore(
            modelContainer: modelContainer,
            crossDeviceChannel: NoopCrossDeviceTrackingChannel()
        )
    }

    var body: some View {
        WorkspaceDetailAreaView(
            viewModel: viewModel,
            section: .tracking,
            showsWorkspaceTabBar: true,
            projects: [project],
            activeSessions: [],
            dependencies: .live(configuration: TimeTrackerTargetConfiguration.macOS),
            modelContext: modelContainer.mainContext,
            trackingStatus: trackingStatus
        )
        .modelContainer(modelContainer)
    }

    private static func makeModelContainer() -> ModelContainer {
        do {
            return try TimeTrackerSchema.makeModelContainer(isStoredInMemoryOnly: true)
        } catch {
            fatalError("WorkspaceDetailAreaView preview model container could not be created: \(error)")
        }
    }
}

