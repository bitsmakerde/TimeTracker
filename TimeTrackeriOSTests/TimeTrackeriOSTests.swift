import SwiftData
import SwiftUI
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

    @Test("Project creation draft saves a new client project")
    func projectCreationDraftCreatesNewClientProject() throws {
        var draft = ProjectCreationDraft()
        draft.clientName = "  Neuer Kunde  "
        draft.projectName = "  Website Relaunch  "
        draft.notes = "Discovery und Umsetzung"
        draft.hourlyRateText = "95,5"

        #expect(draft.canSave)

        let project = try #require(draft.makeProject())
        #expect(project.displayClientName == "Neuer Kunde")
        #expect(project.displayName == "Website Relaunch")
        #expect(project.notes == "Discovery und Umsetzung")
        #expect(project.hourlyRate == 95.5)
    }

    @Test("Project creation draft keeps an existing client prefilled")
    func projectCreationDraftPrefillsExistingClient() throws {
        var draft = ProjectCreationDraft(initialClientName: "Bestandskunde")
        draft.projectName = "iOS App"

        let project = try #require(draft.makeProject())
        #expect(project.displayClientName == "Bestandskunde")
        #expect(project.displayName == "iOS App")
    }

    @Test("Project creation draft rejects invalid input and stores custom color")
    func projectCreationDraftValidationAndCustomColor() throws {
        var invalidDraft = ProjectCreationDraft(initialClientName: "Kunde")
        invalidDraft.projectName = "   "
        invalidDraft.hourlyRateText = "abc"

        #expect(invalidDraft.hasInvalidHourlyRate)
        #expect(invalidDraft.canSave == false)
        #expect(invalidDraft.makeProject() == nil)

        var draft = ProjectCreationDraft(initialClientName: "Kunde")
        draft.projectName = "iOS App"
        draft.usesCustomProjectColor = true
        draft.projectColor = .pink

        let project = try #require(draft.makeProject())
        #expect(project.hasCustomAccentColor)
    }

    @Test("iOS target configuration enables compact navigation")
    func iOSTargetConfiguration() {
        let configuration = TimeTrackerTargetConfiguration.iOS

        #expect(configuration.platform == .iOS)
        #expect(configuration.featureFlags.usesNativeCompactTabBar)
        #expect(configuration.featureFlags.showsMenuBarModule == false)
        #expect(configuration.featureFlags.enablesPreparedExports)
    }

    @Test("Preview sample data links projects and active sessions")
    func previewSampleDataLinksProjectsAndActiveSessions() throws {
        let projects = ClientProject.sampleData
        let activeSessions = WorkSession.sampleActiveData(for: projects)

        #expect(projects.count == 3)
        #expect(projects.contains { $0.isArchived })
        #expect(activeSessions.count == 1)
        #expect(activeSessions.contains { !$0.isActive } == false)

        let activeProject = try #require(activeSessions.first?.project)
        #expect(projects.contains { $0.id == activeProject.id })
        #expect(activeProject.taskList.isEmpty == false)
        #expect(activeProject.sessionList.contains { $0.id == activeSessions.first?.id })
    }

    @Test("Shared analytics aggregator runs in iOS target")
    func sharedAnalyticsAggregatorRunsInIOSTarget() throws {
        let calendar = Calendar.current
        let referenceDate = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 5, day: 14, hour: 12))
        )
        let startOfToday = calendar.startOfDay(for: referenceDate)
        let project = ClientProject(
            clientName: "Mobile",
            name: "App",
            hourlyRate: 80
        )
        project.sessions = [
            WorkSession(
                project: project,
                startedAt: startOfToday.addingTimeInterval(9 * 3_600),
                endedAt: startOfToday.addingTimeInterval(11 * 3_600)
            ),
        ]

        let snapshot = AnalyticsAggregator.snapshot(
            projects: [project],
            referenceDate: referenceDate
        )

        #expect(snapshot.totalDuration == 7_200)
        #expect(snapshot.todayDuration == 7_200)
        #expect(snapshot.totalValue == 160)
        #expect(snapshot.projectBars.map(\.projectId) == [project.id])
        #expect(snapshot.day.count == 24)
    }
}
