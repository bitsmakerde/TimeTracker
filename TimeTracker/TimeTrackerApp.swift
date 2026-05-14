import Foundation
import SwiftData
import SwiftUI

@main
struct TimeTrackerApp: App {
    private let sharedModelContainer: ModelContainer
    private let dependencies: AppDependencies
    @State private var trackingStatus: TrackingStatusStore

    init() {
        do {
            let syncMode: TimeTrackerSyncMode = if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
                .cloudKitPrivate(containerIdentifier: TimeTrackerSchema.defaultCloudKitContainerIdentifier)
            } else {
                .localOnly
            }
            let container = try TimeTrackerSchema.makeModelContainer(syncMode: syncMode)
            self.sharedModelContainer = container
            self.dependencies = AppDependencies.live(
                configuration: TimeTrackerTargetConfiguration.macOS
            )
            _trackingStatus = State(
                wrappedValue: TrackingStatusStore(
                    modelContainer: container,
                    syncMode: syncMode
                )
            )
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MacRedesignedRootView(
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
