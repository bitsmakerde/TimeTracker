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

    @Test("Preview helpers provide iOS dependencies and an active tracking store")
    func previewHelpersProvideDependenciesAndStore() throws {
        let container = ModelContainer.preview
        let context = container.mainContext
        let project = ClientProject(clientName: "Preview", name: "iOS Store")
        let session = WorkSession(
            project: project,
            startedAt: Date(timeIntervalSince1970: 100)
        )

        context.insert(project)
        context.insert(session)
        try context.save()

        let dependencies = AppDependencies.preview
        let trackingStatus = TrackingStatusStore.preview(modelContainer: container)
        trackingStatus.refresh()

        #expect(dependencies.configuration.platform == .iOS)
        #expect(trackingStatus.isTracking)
        #expect(trackingStatus.activeSession?.projectName == "iOS Store")
    }

    @Test("Workspace analytics calculator runs inside the iOS target")
    func sharedAnalyticsCalculatorRunsInIOSTarget() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))

        func date(year: Int, month: Int, day: Int, hour: Int) throws -> Date {
            try #require(
                calendar.date(
                    from: DateComponents(
                        timeZone: calendar.timeZone,
                        year: year,
                        month: month,
                        day: day,
                        hour: hour
                    )
                )
            )
        }

        let billableProject = ClientProject(
            clientName: "Mobile",
            name: "App",
            hourlyRate: 100
        )
        let unbilledProject = ClientProject(
            clientName: "Mobile",
            name: "Discovery"
        )
        billableProject.sessions = [
            WorkSession(
                project: billableProject,
                startedAt: try date(year: 2026, month: 5, day: 14, hour: 9),
                endedAt: try date(year: 2026, month: 5, day: 14, hour: 11)
            ),
        ]
        unbilledProject.sessions = [
            WorkSession(
                project: unbilledProject,
                startedAt: try date(year: 2026, month: 5, day: 14, hour: 11),
                endedAt: try date(year: 2026, month: 5, day: 14, hour: 13)
            ),
        ]

        let snapshot = AnalyticsCalculator.makeSnapshot(
            projects: [unbilledProject, billableProject],
            referenceDate: try date(year: 2026, month: 5, day: 14, hour: 14),
            calendar: calendar
        )

        #expect(snapshot.totalDuration == 14_400)
        #expect(snapshot.totalBilledAmount == 200)
        #expect(snapshot.totalValueText == TimeFormatting.euroAmount(200))
        #expect(snapshot.hasHourlyData)
        #expect(snapshot.projectTotals.map(\.projectName) == ["App", "Discovery"])
        #expect(snapshot.projectTotals.last?.valueText == "Kein Stundensatz")
    }
}

@Suite("iOS View Rendering")
@MainActor
struct TimeTrackeriOSViewRenderingTests {
    @Test("iOS screens render with preview data")
    func iOSViewsRender() throws {
        let preview = PreviewWorkspaceSnapshot()
        let dependencies = AppDependencies.preview
        let viewModel = WorkspaceRootViewModel()
        viewModel.ensureInitialSelection(projects: preview.projects)

        ViewRenderTestSupport.assertRenders(
            ContentView(
                trackingStatus: preview.trackingStatus,
                dependencies: dependencies
            )
            .modelContainer(preview.modelContainer),
            width: 430,
            height: 932
        )
        ViewRenderTestSupport.assertRenders(
            TrackingScreen(
                trackingStatus: preview.trackingStatus,
                dependencies: dependencies
            )
            .modelContainer(preview.modelContainer),
            width: 430,
            height: 1200
        )
        ViewRenderTestSupport.assertRenders(
            SyncBanner(lastSyncedAt: Date(timeIntervalSince1970: 1_779_000_000)),
            width: 120,
            height: 120
        )
        ViewRenderTestSupport.assertRenders(
            AnalyticsScreen(trackingStatus: preview.trackingStatus)
                .modelContainer(preview.modelContainer),
            width: 430,
            height: 1200
        )
        ViewRenderTestSupport.assertRenders(
            ProjectsDrawer(
                projects: preview.projects,
                activeProjectId: preview.activeSessions.first?.project?.id,
                onSelect: { _ in },
                onAddProject: { _ in }
            ),
            width: 430,
            height: 900
        )
        ViewRenderTestSupport.assertRenders(
            WorkspaceCompactTabRootView(
                viewModel: viewModel,
                projects: preview.projects,
                activeSessions: preview.activeSessions,
                dependencies: dependencies,
                modelContext: preview.modelContainer.mainContext,
                trackingStatus: preview.trackingStatus
            )
            .modelContainer(preview.modelContainer),
            width: 430,
            height: 932
        )
        ViewRenderTestSupport.assertRenders(
            ToolbarRenderHost(
                content: WorkspaceCompactTrackingToolbar(
                    viewModel: viewModel,
                    activeProjects: viewModel.activeProjects(from: preview.projects),
                    hasActiveSession: preview.activeSessions.isEmpty == false,
                    dependencies: dependencies,
                    modelContext: preview.modelContainer.mainContext,
                    trackingStatus: preview.trackingStatus
                )
            ),
            width: 430,
            height: 120
        )
    }

    @Test("iOS app can be constructed in tests")
    func iOSAppCanBeConstructed() {
        let app = TimeTrackeriOSApp()

        _ = app.body
    }
}

@MainActor
private enum ViewRenderTestSupport {
    static func assertRenders<V: View>(
        _ view: V,
        width: CGFloat,
        height: CGFloat
    ) {
        let renderer = ImageRenderer(
            content: view
                .frame(width: width, height: height, alignment: .topLeading)
        )
        renderer.scale = 1
        #expect(renderer.uiImage != nil)
    }
}

private struct ToolbarRenderHost<Content: ToolbarContent>: View {
    let content: Content

    var body: some View {
        NavigationStack {
            Text("Toolbar")
        }
        .toolbar {
            content
        }
    }
}
