import SwiftData
import SwiftUI

struct ContentView: View {
    let trackingStatus: TrackingStatusStore
    let dependencies: AppDependencies

    var body: some View {
        TabView {
            Tab("Aufnehmen", systemImage: "record.circle") {
                WorkspaceRootView(
                    trackingStatus: trackingStatus,
                    dependencies: dependencies,
                    forcedWorkspaceSection: .tracking,
                    showsWorkspaceSectionPicker: false
                )
            }

            Tab("Auswertung", systemImage: "chart.bar.xaxis") {
                WorkspaceRootView(
                    trackingStatus: trackingStatus,
                    dependencies: dependencies,
                    forcedWorkspaceSection: .analytics,
                    showsWorkspaceSectionPicker: false
                )
            }
        }
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(.regularMaterial, for: .tabBar)
    }
}

#Preview {
    let previewContainer: ModelContainer = {
        do {
            return try TimeTrackerSchema.makeModelContainer(
                isStoredInMemoryOnly: true
            )
        } catch {
            fatalError("Failed to create preview container: \(error)")
        }
    }()

    return ContentView(
        trackingStatus: TrackingStatusStore(modelContainer: previewContainer),
        dependencies: AppDependencies.live(
            configuration: TimeTrackerTargetConfiguration.iOS
        )
    )
    .modelContainer(previewContainer)
}
