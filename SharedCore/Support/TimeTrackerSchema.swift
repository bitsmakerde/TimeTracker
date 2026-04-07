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
