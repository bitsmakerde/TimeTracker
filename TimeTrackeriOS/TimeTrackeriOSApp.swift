//
//  TimeTrackeriOSApp.swift
//  TimeTrackeriOS
//
//  Created by André Bongartz on 06.04.26.
//

import SwiftData
import SwiftUI

@main
struct TimeTrackeriOSApp: App {
    private let sharedModelContainer: ModelContainer
    private let dependencies: AppDependencies
    @State private var trackingStatus: TrackingStatusStore

    init() {
        do {
            let container = try TimeTrackerSchema.makeModelContainer()
            self.sharedModelContainer = container
            self.dependencies = AppDependencies.live(
                configuration: TimeTrackerTargetConfiguration.iOS
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
            ContentView(
                trackingStatus: trackingStatus,
                dependencies: dependencies
            )
        }
        .modelContainer(sharedModelContainer)
    }
}
