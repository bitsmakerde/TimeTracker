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
    @State private var trackingStatus: TrackingStatusStore

    init() {
        do {
            let container = try TimeTrackerSchema.makeModelContainer()
            self.sharedModelContainer = container
            _trackingStatus = State(
                wrappedValue: TrackingStatusStore(modelContainer: container)
            )
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(trackingStatus: trackingStatus)
        }
        .modelContainer(sharedModelContainer)
    }
}
