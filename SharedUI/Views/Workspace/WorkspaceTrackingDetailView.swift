import SwiftData
import SwiftUI

struct WorkspaceTrackingDetailView: View {
    @Bindable var viewModel: WorkspaceRootViewModel
    let projects: [ClientProject]
    let activeSessions: [WorkSession]
    let dependencies: AppDependencies
    let modelContext: ModelContext
    let trackingStatus: TrackingStatusStore

    var body: some View {
        if let selectedProject = viewModel.selectedProject(in: projects) {
            ProjectDetailView(
                project: selectedProject,
                activeSession: viewModel.activeSession(from: activeSessions),
                onStart: {
                    startTracking(selectedProject)
                },
                onStartTask: { task in
                    startTracking(selectedProject, task: task)
                },
                onStop: stopActiveTracking,
                onAddManualEntry: {
                    viewModel.presentManualSessionSheet()
                },
                onEditSession: { session in
                    viewModel.editSession(session, project: selectedProject)
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
                viewModel.presentNewProjectSheet()
            }
        }
    }

    private func startTracking(_ project: ClientProject, task: ProjectTask? = nil) {
        viewModel.startTracking(
            project,
            task: task,
            dependencies: dependencies,
            modelContext: modelContext,
            trackingStatus: trackingStatus
        )
    }

    private func stopActiveTracking() {
        viewModel.stopActiveTracking(
            dependencies: dependencies,
            modelContext: modelContext,
            trackingStatus: trackingStatus
        )
    }

    private func deleteSession(_ session: WorkSession) {
        viewModel.deleteSession(
            session,
            dependencies: dependencies,
            modelContext: modelContext,
            trackingStatus: trackingStatus
        )
    }

    private func archiveProject(_ project: ClientProject) {
        viewModel.archiveProject(
            project,
            dependencies: dependencies,
            modelContext: modelContext,
            trackingStatus: trackingStatus
        )
    }

    private func restoreProject(_ project: ClientProject) {
        viewModel.restoreProject(
            project,
            dependencies: dependencies,
            modelContext: modelContext,
            trackingStatus: trackingStatus
        )
    }

    private func deleteProject(_ project: ClientProject) {
        viewModel.deleteProject(
            project,
            dependencies: dependencies,
            modelContext: modelContext,
            trackingStatus: trackingStatus
        )
    }
}

#Preview {
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

    WorkspaceTrackingDetailView(
        viewModel: .init(),
        projects: [project],
        activeSessions: [],
        dependencies: .live(configuration: TimeTrackerTargetConfiguration.macOS),
        modelContext: try! TimeTrackerSchema.makeModelContainer(isStoredInMemoryOnly: true).mainContext,
        trackingStatus: TrackingStatusStore(modelContainer: try! TimeTrackerSchema.makeModelContainer(isStoredInMemoryOnly: true), syncMode: .localOnly)
    )
}
