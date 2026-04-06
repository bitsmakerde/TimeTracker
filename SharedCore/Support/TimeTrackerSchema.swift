import SwiftData

enum TimeTrackerSchema {
    static var schema: Schema {
        Schema([
            ClientProject.self,
            ProjectTask.self,
            WorkSession.self,
        ])
    }

    static func makeModelContainer(
        isStoredInMemoryOnly: Bool = false
    ) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )

        return try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }
}
