import SwiftData
import Testing
@testable import TimeTrackeriOS

@Suite("iOS Smoke")
@MainActor
struct TimeTrackeriOSTests {
    @Test("Shared schema can be used by iOS target")
    func sharedSchemaContainer() throws {
        let container = try TimeTrackerSchema.makeModelContainer(
            isStoredInMemoryOnly: true
        )
        let context = container.mainContext
        let project = ClientProject(clientName: "Smoke", name: "iOS")

        context.insert(project)
        try context.save()

        let projects = try context.fetch(FetchDescriptor<ClientProject>())
        #expect(projects.count == 1)
        #expect(projects.first?.displayName == "iOS")
    }
}
