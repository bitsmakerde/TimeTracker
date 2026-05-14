import SwiftData
import Foundation

extension ClientProject {
    static var sampleData: [ClientProject] {
        let websiteProject = ClientProject(
            clientName: "Acme Corp",
            name: "Website Redesign",
            hourlyRate: 85,
            budgetUnitRaw: ProjectBudgetUnit.hours.rawValue,
            budgetTarget: 24,
            accentRed: 0.0,
            accentGreen: 0.48,
            accentBlue: 1.0,
            createdAt: .now.addingTimeInterval(-21 * 86_400)
        )
        let landingPageTask = ProjectTask(
            title: "Landing Page",
            project: websiteProject,
            createdAt: .now.addingTimeInterval(-20 * 86_400)
        )
        let activeSession = WorkSession(
            project: websiteProject,
            task: landingPageTask,
            startedAt: .now.addingTimeInterval(-3_600)
        )
        let discoverySession = WorkSession(
            project: websiteProject,
            task: landingPageTask,
            startedAt: .now.addingTimeInterval(-2 * 86_400),
            endedAt: .now.addingTimeInterval(-2 * 86_400 + 7_200)
        )
        websiteProject.tasks = [landingPageTask]
        websiteProject.sessions = [activeSession, discoverySession]

        let appProject = ClientProject(
            clientName: "Northwind",
            name: "iOS App",
            hourlyRate: 110,
            budgetUnitRaw: ProjectBudgetUnit.amount.rawValue,
            budgetTarget: 12_000,
            accentRed: 0.20,
            accentGreen: 0.78,
            accentBlue: 0.35,
            createdAt: .now.addingTimeInterval(-14 * 86_400)
        )
        let implementationTask = ProjectTask(
            title: "SwiftUI Screens",
            project: appProject,
            createdAt: .now.addingTimeInterval(-13 * 86_400)
        )
        appProject.tasks = [implementationTask]
        appProject.sessions = [
            WorkSession(
                project: appProject,
                task: implementationTask,
                startedAt: .now.addingTimeInterval(-86_400),
                endedAt: .now.addingTimeInterval(-86_400 + 5_400)
            ),
        ]

        let archivedProject = ClientProject(
            clientName: "Archiv GmbH",
            name: "Relaunch 2024",
            archivedAt: .now.addingTimeInterval(-7 * 86_400),
            accentRed: 1.0,
            accentGreen: 0.58,
            accentBlue: 0.0,
            createdAt: .now.addingTimeInterval(-120 * 86_400)
        )

        return [websiteProject, appProject, archivedProject]
    }
}

extension WorkSession {
    static var sampleActiveData: [WorkSession] {
        sampleActiveData(for: ClientProject.sampleData)
    }

    static func sampleActiveData(for projects: [ClientProject]) -> [WorkSession] {
        projects.flatMap(\.sessionList).filter(\.isActive)
    }
}

extension ModelContainer {
    @MainActor
    static var preview: ModelContainer {
        do {
            return try TimeTrackerSchema.makeModelContainer(isStoredInMemoryOnly: true)
        } catch {
            fatalError("Failed to create preview model container: \(error)")
        }
    }
}

extension AppDependencies {
    static var preview: AppDependencies {
        .live(configuration: TimeTrackerTargetConfiguration.iOS)
    }
}

extension TrackingStatusStore {
    @MainActor
    static func preview(modelContainer: ModelContainer) -> TrackingStatusStore {
        TrackingStatusStore(
            modelContainer: modelContainer,
            crossDeviceChannel: NoopCrossDeviceTrackingChannel()
        )
    }
}
