import SwiftData
@testable import TimeTracker

@MainActor
enum TestSupport {
    static func makeInMemoryContainer() throws -> ModelContainer {
        try TimeTrackerSchema.makeModelContainer(
            isStoredInMemoryOnly: true
        )
    }
}
