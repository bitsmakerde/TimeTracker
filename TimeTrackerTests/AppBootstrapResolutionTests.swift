import Foundation
import SwiftData
import Testing
@testable import TimeTracker

@Suite("App Bootstrap Resolution")
struct AppBootstrapResolutionTests {
    @Test("Resolves in-memory when XCTestConfigurationFilePath is present")
    func resolvesInMemoryUnderXCTest() {
        let decision = TimeTrackerBootstrapDecision.resolve(
            environment: ["XCTestConfigurationFilePath": "/tmp/fake.xctest"],
            arguments: ["TimeTracker"],
            cloudKitContainerIdentifier: "iCloud.test"
        )

        #expect(decision.isStoredInMemoryOnly)
        #expect(decision.syncMode == .localOnly)
    }

    @Test("Resolves in-memory when -uiTestInMemory launch argument is present")
    func resolvesInMemoryWithLaunchArgument() {
        let decision = TimeTrackerBootstrapDecision.resolve(
            environment: [:],
            arguments: ["TimeTracker", "-uiTestInMemory"],
            cloudKitContainerIdentifier: "iCloud.test"
        )

        #expect(decision.isStoredInMemoryOnly)
        #expect(decision.syncMode == .localOnly)
    }

    @Test("Resolves CloudKit production by default")
    func resolvesCloudKitInProduction() {
        let decision = TimeTrackerBootstrapDecision.resolve(
            environment: [:],
            arguments: ["TimeTracker"],
            cloudKitContainerIdentifier: "iCloud.test"
        )

        #expect(decision.isStoredInMemoryOnly == false)
        #expect(decision.syncMode == .cloudKitPrivate(containerIdentifier: "iCloud.test"))
    }

    @Test("Ignores XCTest hint when it is the empty string")
    func ignoresEmptyXCTestHint() {
        let decision = TimeTrackerBootstrapDecision.resolve(
            environment: ["XCTestConfigurationFilePath": ""],
            arguments: ["TimeTracker"],
            cloudKitContainerIdentifier: "iCloud.test"
        )

        #expect(decision.isStoredInMemoryOnly == false)
    }

    @Test("Resolves in-memory when an injected xctest bundle is present")
    func resolvesInMemoryWithInjectedTestBundle() {
        let decision = TimeTrackerBootstrapDecision.resolve(
            environment: [:],
            arguments: ["TimeTracker"],
            loadedBundlePaths: ["/tmp/TimeTrackerTests.xctest"]
        )

        #expect(decision.isStoredInMemoryOnly)
        #expect(decision.syncMode == .localOnly)
    }

    @MainActor
    @Test("makeAppLaunchContainer returns an in-memory container under test")
    func makeAppLaunchContainerHonoursInMemoryDecision() throws {
        let launch = try TimeTrackerSchema.makeAppLaunchContainer(
            environment: ["XCTestConfigurationFilePath": "/tmp/fake.xctest"],
            arguments: [],
            cloudKitContainerIdentifier: "iCloud.test"
        )

        #expect(launch.decision.isStoredInMemoryOnly)
        #expect(launch.decision.syncMode == .localOnly)

        let context = launch.container.mainContext
        context.insert(ClientProject(clientName: "Smoke", name: "Bootstrap"))
        try context.save()
    }

    @MainActor
    @Test("makeAppLaunchContainer uses in-memory storage for injected app-host tests")
    func makeAppLaunchContainerHonoursInjectedBundleDecision() throws {
        let launch = try TimeTrackerSchema.makeAppLaunchContainer(
            environment: [:],
            arguments: ["TimeTracker"],
            loadedBundlePaths: ["/tmp/TimeTrackerTests.xctest"]
        )

        #expect(launch.decision.isStoredInMemoryOnly)
        #expect(launch.decision.syncMode == .localOnly)
    }
}
