import SwiftData
import SwiftUI

@main
struct TimeTrackerApp: App {
    private let sharedModelContainer: ModelContainer
    private let dependencies: AppDependencies
    @State private var trackingStatus: TrackingStatusStore

    init() {
        do {
            let container = try TimeTrackerSchema.makeModelContainer()
            self.sharedModelContainer = container
            self.dependencies = AppDependencies.live(
                configuration: TimeTrackerTargetConfiguration.macOS
            )
            _trackingStatus = State(
                wrappedValue: TrackingStatusStore(modelContainer: container)
            )
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            WorkspaceRootView(
                trackingStatus: trackingStatus,
                dependencies: dependencies
            )
                .frame(minWidth: 1100, minHeight: 720)
        }
        .modelContainer(sharedModelContainer)

        MenuBarExtra {
            MenuBarTrackingView(
                trackingStatus: trackingStatus,
                dependencies: dependencies
            )
        } label: {
            MenuBarStatusLabel(trackingStatus: trackingStatus)
        }
        .modelContainer(sharedModelContainer)
        .menuBarExtraStyle(.window)
    }
}
