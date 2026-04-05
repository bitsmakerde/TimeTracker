import SwiftData
@testable import TimeTracker

@MainActor
enum TestSupport {
    static func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([
            ClientProject.self,
            ProjectTask.self,
            WorkSession.self,
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        return try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }
}
