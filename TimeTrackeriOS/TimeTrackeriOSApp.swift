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
            let launch = try TimeTrackerSchema.makeAppLaunchContainer()
            self.sharedModelContainer = launch.container
            self.dependencies = AppDependencies.live(
                configuration: TimeTrackerTargetConfiguration.iOS
            )
            _trackingStatus = State(
                wrappedValue: TrackingStatusStore(
                    modelContainer: launch.container,
                    syncMode: launch.decision.syncMode
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
