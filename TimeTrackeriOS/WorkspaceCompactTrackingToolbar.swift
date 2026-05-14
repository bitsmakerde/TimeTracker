
import SwiftData
import SwiftUI

struct WorkspaceCompactTrackingToolbar: ToolbarContent {
    @Bindable var viewModel: WorkspaceRootViewModel
    let activeProjects: [ClientProject]
    let hasActiveSession: Bool
    let dependencies: AppDependencies
    let modelContext: ModelContext
    let trackingStatus: TrackingStatusStore

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                if activeProjects.isEmpty {
                    Text("Keine Projekte")
                } else {
                    ForEach(activeProjects) { project in
                        Button {
                            viewModel.selectProject(project)
                        } label: {
                            Label(
                                project.displayName,
                                systemImage: viewModel.selectedProjectID == project.id ? "checkmark" : "circle"
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
                viewModel.presentNewProjectSheet()
            } label: {
                Label("Projekt", systemImage: "plus")
            }
        }

        if hasActiveSession {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    viewModel.stopActiveTracking(
                        dependencies: dependencies,
                        modelContext: modelContext,
                        trackingStatus: trackingStatus
                    )
                } label: {
                    Label("Stopp", systemImage: "stop.fill")
                }
            }
        }
    }
}

