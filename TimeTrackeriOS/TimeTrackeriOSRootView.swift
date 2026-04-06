import SwiftData
import SwiftUI

struct ContentView: View {
    let trackingStatus: TrackingStatusStore

    var body: some View {
        TabView {
            Tab("Aufnehmen", systemImage: "record.circle") {
                WorkspaceRootView(
                    trackingStatus: trackingStatus,
                    forcedWorkspaceSection: .tracking,
                    showsWorkspaceSectionPicker: false
                )
            }

            Tab("Auswertung", systemImage: "chart.bar.xaxis") {
                WorkspaceRootView(
                    trackingStatus: trackingStatus,
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
        trackingStatus: TrackingStatusStore(modelContainer: previewContainer)
    )
    .modelContainer(previewContainer)
}
