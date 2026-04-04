import SwiftData
import SwiftUI

@main
struct TimeTrackerApp: App {
    private let sharedModelContainer: ModelContainer
    @StateObject private var trackingStatus: TrackingStatusStore

    init() {
        let schema = Schema([
            ClientProject.self,
            ProjectTask.self,
            WorkSession.self,
        ])

        // SwiftData stays the single source of truth so CloudKit sync can be
        // added later by switching to a CloudKit-backed configuration.
        let configuration = ModelConfiguration(schema: schema)

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            self.sharedModelContainer = container
            _trackingStatus = StateObject(
                wrappedValue: TrackingStatusStore(modelContainer: container)
            )
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(trackingStatus: trackingStatus)
                .frame(minWidth: 1100, minHeight: 720)
        }
        .modelContainer(sharedModelContainer)

        MenuBarExtra {
            MenuBarTrackingView(trackingStatus: trackingStatus)
        } label: {
            MenuBarStatusLabel(trackingStatus: trackingStatus)
        }
        .modelContainer(sharedModelContainer)
        .menuBarExtraStyle(.window)
    }
}
