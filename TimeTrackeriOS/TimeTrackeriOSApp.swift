//
//  TimeTrackeriOSApp.swift
//  TimeTrackeriOS
//
//  Created by André Bongartz on 06.04.26.
//

import Foundation
import SwiftData
import SwiftUI

@main
struct TimeTrackeriOSApp: App {
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
                configuration: TimeTrackerTargetConfiguration.iOS
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
            ContentView(
                trackingStatus: trackingStatus,
                dependencies: dependencies
            )
        }
        .modelContainer(sharedModelContainer)
    }
}
