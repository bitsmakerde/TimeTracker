import Foundation
import SwiftData

enum TimeTrackerSyncMode: Equatable {
    case localOnly
    case cloudKitPrivate(containerIdentifier: String)
}

struct TimeTrackerBootstrapDecision: Equatable {
    let isStoredInMemoryOnly: Bool
    let syncMode: TimeTrackerSyncMode

    static let inMemoryLaunchArgument = "-uiTestInMemory"

    static func resolve(
        environment: [String: String],
        arguments: [String],
        loadedBundlePaths: [String] = [],
        cloudKitContainerIdentifier: String = TimeTrackerSchema.defaultCloudKitContainerIdentifier
    ) -> TimeTrackerBootstrapDecision {
        let xcTestHint = environment["XCTestConfigurationFilePath"] ?? ""
        let isUnderXCTest = xcTestHint.isEmpty == false
        let hasInjectedTestBundle = loadedBundlePaths.contains { bundlePath in
            URL(fileURLWithPath: bundlePath).pathExtension == "xctest"
        }
        let hasInMemoryArgument = arguments.contains(inMemoryLaunchArgument)
        let shouldUseInMemory = isUnderXCTest || hasInjectedTestBundle || hasInMemoryArgument

        if shouldUseInMemory {
            return TimeTrackerBootstrapDecision(
                isStoredInMemoryOnly: true,
                syncMode: .localOnly
            )
        }

        return TimeTrackerBootstrapDecision(
            isStoredInMemoryOnly: false,
            syncMode: .cloudKitPrivate(containerIdentifier: cloudKitContainerIdentifier)
        )
    }
}

struct TimeTrackerAppLaunch {
    let container: ModelContainer
    let decision: TimeTrackerBootstrapDecision
}

enum TimeTrackerSchema {
    static let defaultCloudKitContainerIdentifier = "iCloud.de.bitsmaker.TimeTracker"

    static var schema: Schema {
        Schema([
            ClientProject.self,
            ProjectTask.self,
            WorkSession.self,
        ])
    }

    static func makeModelContainer(
        isStoredInMemoryOnly: Bool = false,
        syncMode: TimeTrackerSyncMode = .localOnly
    ) throws -> ModelContainer {
        let configuration: ModelConfiguration

        if isStoredInMemoryOnly {
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
        } else {
            switch syncMode {
            case .localOnly:
                configuration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false
                )
            case let .cloudKitPrivate(containerIdentifier):
                configuration = ModelConfiguration(
                    schema: schema,
                    cloudKitDatabase: .private(containerIdentifier)
                )
            }
        }

        return try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }

    static func makeAppLaunchContainer(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        loadedBundlePaths: [String] = Bundle.allBundles.map(\.bundlePath),
        cloudKitContainerIdentifier: String = defaultCloudKitContainerIdentifier
    ) throws -> TimeTrackerAppLaunch {
        let decision = TimeTrackerBootstrapDecision.resolve(
            environment: environment,
            arguments: arguments,
            loadedBundlePaths: loadedBundlePaths,
            cloudKitContainerIdentifier: cloudKitContainerIdentifier
        )
        let container = try makeModelContainer(
            isStoredInMemoryOnly: decision.isStoredInMemoryOnly,
            syncMode: decision.syncMode
        )
        return TimeTrackerAppLaunch(container: container, decision: decision)
    }
}

enum TimeTrackerTargetPlatform: String {
    case macOS
    case iOS
}

struct TimeTrackerFeatureFlags: Equatable {
    var usesNativeCompactTabBar: Bool
    var showsMenuBarModule: Bool
    var enablesPreparedExports: Bool
}

protocol TimeTrackerTargetConfigurationProtocol {
    var platform: TimeTrackerTargetPlatform { get }
    var featureFlags: TimeTrackerFeatureFlags { get }
}

struct TimeTrackerTargetConfiguration: TimeTrackerTargetConfigurationProtocol, Equatable {
    let platform: TimeTrackerTargetPlatform
    let featureFlags: TimeTrackerFeatureFlags

    static let macOS = TimeTrackerTargetConfiguration(
        platform: .macOS,
        featureFlags: TimeTrackerFeatureFlags(
            usesNativeCompactTabBar: false,
            showsMenuBarModule: true,
            enablesPreparedExports: true
        )
    )

    static let iOS = TimeTrackerTargetConfiguration(
        platform: .iOS,
        featureFlags: TimeTrackerFeatureFlags(
            usesNativeCompactTabBar: true,
            showsMenuBarModule: false,
            enablesPreparedExports: true
        )
    )
}

struct AppDependencies {
    let configuration: any TimeTrackerTargetConfigurationProtocol
    let workspaceTrackingUseCases: any WorkspaceTrackingUseCasesProtocol

    static func live(
        configuration: any TimeTrackerTargetConfigurationProtocol,
        trackingManager: any TrackingManagerProtocol = TrackingManager()
    ) -> AppDependencies {
        let repository = SwiftDataTrackingRepository(
            trackingManager: trackingManager
        )
        let useCases = DefaultWorkspaceTrackingUseCases(
            repository: repository
        )
        return AppDependencies(
            configuration: configuration,
            workspaceTrackingUseCases: useCases
        )
    }
}
