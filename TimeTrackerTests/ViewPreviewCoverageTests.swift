import Foundation
import SwiftUI
import Testing
@testable import TimeTracker

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

@Suite("View Preview Coverage")
struct ViewPreviewCoverageTests {
    @Test("Every SwiftUI view file includes a preview")
    func everySwiftUIViewFileIncludesPreview() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceDirectories = ["SharedUI", "TimeTracker", "TimeTrackeriOS"]
            .map { repositoryRoot.appending(path: $0) }

        let missingPreviewFiles = sourceDirectories
            .flatMap(swiftFiles(in:))
            .filter(fileDefinesView)
            .filter { fileHasPreview($0) == false }
            .map { $0.path.replacingOccurrences(of: repositoryRoot.path + "/", with: "") }
            .sorted()

        if missingPreviewFiles.isEmpty == false {
            Issue.record(
                """
                Missing previews:
                \(missingPreviewFiles.joined(separator: "\n"))
                """
            )
        }

        #expect(missingPreviewFiles.isEmpty)
    }

    @Test("Legacy workspace files and duplicate model copies were removed")
    func legacyWorkspaceFilesWereRemoved() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let removedPaths = [
            "SharedUI/Views/ClientGroup.swift",
            "SharedUI/Views/EmptyStateView.swift",
            "SharedUI/Views/PlatformSummaryCard.swift",
            "SharedUI/Views/SessionEditor.swift",
            "SharedUI/Views/Workspace/TabBar/WorkspaceTabBarView.swift",
            "SharedUI/Views/Workspace/TabBar/WorkspaceTabButton.swift",
            "SharedUI/Views/Workspace/ViewModels/WorkspaceRootViewModel.swift",
            "SharedUI/Views/Workspace/WorkspaceDetailAreaView.swift",
            "SharedUI/Views/Workspace/WorkspaceRootLayoutRules.swift",
            "SharedUI/Views/Workspace/WorkspaceSection.swift",
            "SharedUI/Views/Workspace/WorkspaceTrackingDetailView.swift",
            "TimeTracker/Models/ClientProject.swift",
            "TimeTracker/Models/ProjectTask.swift",
            "TimeTracker/Models/WorkSession.swift",
            "TimeTracker/Services/TrackingManager.swift",
            "TimeTracker/Services/TrackingStatusStore.swift",
            "TimeTracker/Support/TimeFormatting.swift",
            "TimeTracker/Views/ContentView.swift",
            "TimeTracker/Views/Workspace/Sidebar/ActiveSidebarCard.swift",
            "TimeTracker/Views/Workspace/Sidebar/ClientSectionHeader.swift",
            "TimeTracker/Views/Workspace/Sidebar/ProjectSidebarRow.swift",
            "TimeTracker/Views/Workspace/Sidebar/WorkspaceSidebarView.swift",
            "TimeTracker/Views/WorkspaceAnalyticsView.swift",
            "TimeTrackerTests/ProjectDetailViewPreviewTests.swift",
            "TimeTrackeriOS/WorkspaceCompactTabRootView.swift",
            "TimeTrackeriOS/WorkspaceCompactTrackingToolbar.swift",
        ]

        for path in removedPaths {
            #expect(fileExists(path, relativeTo: repositoryRoot) == false)
        }

        let projectSource = try String(
            contentsOf: repositoryRoot.appending(path: "TimeTracker.xcodeproj/project.pbxproj"),
            encoding: .utf8
        )
        let macTargetSources = try sourceFileNames(
            inTargetNamed: "TimeTracker",
            projectSource: projectSource
        )
        let removedMacSourceNames: Set<String> = [
            "ActiveSidebarCard.swift",
            "ClientGroup.swift",
            "ClientSectionHeader.swift",
            "ContentView.swift",
            "EmptyStateView.swift",
            "PlatformSummaryCard.swift",
            "ProjectSidebarRow.swift",
            "SessionEditor.swift",
            "WorkspaceAnalyticsView.swift",
            "WorkspaceDetailAreaView.swift",
            "WorkspaceRootLayoutRules.swift",
            "WorkspaceRootViewModel.swift",
            "WorkspaceSection.swift",
            "WorkspaceSidebarView.swift",
            "WorkspaceTabBarView.swift",
            "WorkspaceTabButton.swift",
            "WorkspaceTrackingDetailView.swift",
        ]

        for fileName in removedMacSourceNames {
            #expect(macTargetSources.contains(fileName) == false)
        }
    }

    @Test("Mac toolbar mode buttons expose selected state")
    func macToolbarModeButtonsExposeSelectedState() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appending(path: "TimeTracker/Views/MacRedesignedRootView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("MacModeToolbarButton"))
        #expect(source.contains("isSelected: macMode == \"rec\""))
        #expect(source.contains("isSelected: macMode == \"rep\""))
        #expect(source.contains("accessibilityAddTraits(isSelected ? .isSelected : [])"))
    }

    private func swiftFiles(in directory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        return enumerator.compactMap { element in
            guard let url = element as? URL,
                  url.pathExtension == "swift" else {
                return nil
            }

            return url
        }
    }

    private func fileDefinesView(_ fileURL: URL) -> Bool {
        guard let source = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return false
        }

        return source.range(
            of: #"(?m)^\s*(private\s+)?(struct|enum|final class)\s+\w+\s*:\s*View\b"#,
            options: .regularExpression
        ) != nil
    }

    private func fileHasPreview(_ fileURL: URL) -> Bool {
        guard let source = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return false
        }

        return source.contains("#Preview") || source.contains("PreviewProvider")
    }

    private func fileExists(_ relativePath: String, relativeTo root: URL) -> Bool {
        FileManager.default.fileExists(atPath: root.appending(path: relativePath).path)
    }

    private func sourceFileNames(
        inTargetNamed targetName: String,
        projectSource: String
    ) throws -> Set<String> {
        let escapedTargetName = escapedForRegex(targetName)
        let targetPattern =
            "(?s)[A-F0-9]+ /\\* \(escapedTargetName) \\*/ = \\{\\s*isa = PBXNativeTarget;.*?buildPhases = \\((.*?)\\);.*?name = \(escapedTargetName);"
        let buildPhaseList = try captureGroup(
            pattern: targetPattern,
            in: projectSource
        )
        let sourcesPhaseID = try captureGroup(
            pattern: #"([A-F0-9]+) /\* Sources \*/"#,
            in: buildPhaseList
        )

        let sourcesPattern =
            "(?s)\(escapedForRegex(sourcesPhaseID)) /\\* Sources \\*/ = \\{.*?files = \\((.*?)\\);"
        let filesList = try captureGroup(
            pattern: sourcesPattern,
            in: projectSource
        )
        let regex = try NSRegularExpression(
            pattern: #"/\* ([^*]+?\.swift) in Sources \*/"#,
            options: []
        )
        let range = NSRange(filesList.startIndex..., in: filesList)

        return Set(regex.matches(in: filesList, options: [], range: range).compactMap { match in
            guard let range = Range(match.range(at: 1), in: filesList) else {
                return nil
            }

            return String(filesList[range])
        })
    }

    private func captureGroup(
        pattern: String,
        in text: String
    ) throws -> String {
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..., in: text)

        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let captureRange = Range(match.range(at: 1), in: text) else {
            throw TargetMembershipError.patternNotFound(pattern)
        }

        return String(text[captureRange])
    }

    private func escapedForRegex(_ text: String) -> String {
        NSRegularExpression.escapedPattern(for: text)
    }
}

@Suite("View Rendering")
@MainActor
struct ViewRenderingTests {
    @Test("Current macOS and shared views render with preview data")
    func currentMacAndSharedViewsRender() throws {
        let preview = PreviewWorkspaceSnapshot()
        let dependencies = AppDependencies.live(configuration: TimeTrackerTargetConfiguration.macOS)
        let activeSession = try #require(preview.activeSessions.first)
        let activeProject = try #require(activeSession.project)
        ViewRenderTestSupport.assertRenders(
            SyncBanner(lastSyncedAt: Date(timeIntervalSince1970: 1_779_000_000)),
            width: 620,
            height: 160
        )
        ViewRenderTestSupport.assertRenders(
            SyncBanner(
                lastSyncedAt: Date(timeIntervalSince1970: 1_779_000_000),
                presentation: .compactExpandable
            ),
            width: 120,
            height: 120
        )
        ViewRenderTestSupport.assertRenders(
            TimerHero(
                clientName: activeProject.displayClientName,
                projectName: activeProject.displayName,
                taskName: activeSession.task?.displayTitle,
                projectColor: activeProject.projectAccentColor,
                elapsed: 0,
                hourlyRate: activeProject.hourlyRate,
                billed: 0,
                budgetProgress: 0.25,
                runningSinceLabel: nil,
                compact: true,
                isThisRunning: false,
                onStart: { },
                onPause: nil,
                onStop: nil
            )
            .environment(\.projectColorVariant, .tinted),
            width: 520,
            height: 260
        )
        ViewRenderTestSupport.assertRenders(
            TimerHero(
                clientName: activeProject.displayClientName,
                projectName: activeProject.displayName,
                taskName: activeSession.task?.displayTitle,
                projectColor: activeProject.projectAccentColor,
                elapsed: 3_600,
                hourlyRate: activeProject.hourlyRate,
                billed: 85,
                budgetProgress: 0.4,
                runningSinceLabel: TimeFormatting.shortTime(activeSession.startedAt),
                compact: false,
                isThisRunning: true,
                onStart: nil,
                onPause: { },
                onStop: { }
            )
            .environment(\.projectColorVariant, .chromed),
            width: 520,
            height: 260
        )
        ViewRenderTestSupport.assertRenders(
            MacAufnehmenPane(
                project: activeProject,
                activeSession: activeSession,
                onStartTask: { _ in },
                onStartProject: { },
                onStop: { },
                onAddManualEntry: { },
                onEditEntry: { _ in },
                onEditTask: { _ in },
                onAddTask: { _ in }
            )
            .modelContainer(preview.modelContainer),
            width: 1200,
            height: 900
        )
        ViewRenderTestSupport.assertRenders(
            MacAuswertungPane(
                projects: preview.projects,
                syncStatus: preview.trackingStatus.syncStatus
            ),
            width: 1200,
            height: 900
        )
        ViewRenderTestSupport.assertRenders(
            MacRedesignedRootView(
                trackingStatus: preview.trackingStatus,
                dependencies: dependencies
            )
            .modelContainer(preview.modelContainer),
            width: 1340,
            height: 860
        )
        ViewRenderTestSupport.assertRenders(
            MenuBarTrackingView(
                trackingStatus: preview.trackingStatus,
                dependencies: dependencies
            )
            .modelContainer(preview.modelContainer),
            width: 340,
            height: 620
        )
    }

    @Test("Project detail views render with preview data")
    func projectDetailViewsRender() throws {
        let preview = PreviewWorkspaceSnapshot()
        let project = try #require(preview.projects.first)
        let activeSession = preview.activeSessions.first
        let endedSession = try #require(project.sortedSessions.first(where: { !$0.isActive }))
        let task = try #require(project.sortedTasks.first)
        let viewModel = ProjectDetailViewModel(project: project, activeSession: activeSession)
        viewModel.isEditingHourlyRate = true
        viewModel.isEditingBudgetInSheet = true
        viewModel.isPresentingBudgetSheet = true
        viewModel.isPresentingExportSheet = true
        viewModel.syncHourlyRateText()
        viewModel.syncBudgetEditor()
        viewModel.syncExportConfiguration()

        ViewRenderTestSupport.assertRenders(
            SummaryCard(
                title: "Gesamtzeit",
                value: "12h 30m",
                subtitle: "4 Sitzungen"
            ),
            width: 260,
            height: 160
        )
        ViewRenderTestSupport.assertRenders(
            BudgetProgressDonut(
                snapshot: ProjectBudgetSnapshot(
                    unit: .hours,
                    target: 24,
                    consumed: 11.5
                ),
                accentColor: project.projectActionColor
            ),
            width: 220,
            height: 220
        )
        ViewRenderTestSupport.assertRenders(
            TaskSummaryRow(
                title: task.displayTitle,
                subtitle: "2 Eintraege",
                durationText: "02:00:00",
                valueText: TimeFormatting.euroAmount(170),
                isActive: false,
                isSelectedForStart: true,
                isProjectRunningWithoutTask: false,
                accentColor: project.projectActionColor,
                isArchived: false,
                onSelectForStart: { },
                onStart: { },
                onStop: { }
            ),
            width: 760,
            height: 180
        )
        ViewRenderTestSupport.assertRenders(
            SessionRow(
                session: endedSession,
                hourlyRate: project.hourlyRate,
                availableTasks: project.sortedTasks,
                onAssignToTask: { _ in },
                onCreateTaskAndAssign: { },
                onEdit: { },
                onDelete: { }
            ),
            width: 760,
            height: 180
        )
        ViewRenderTestSupport.assertRenders(
            NewTaskAssignmentSheet(
                project: project,
                session: endedSession,
                onSave: { _ in true }
            ),
            width: 520,
            height: 340
        )
        ViewRenderTestSupport.assertRenders(
            ProjectDetailHeaderCard(
                viewModel: viewModel,
                onStart: { },
                onStartTask: { _ in },
                onStop: { },
                onAddManualEntry: { },
                onArchiveProject: { },
                onRestoreProject: { },
                onDeleteProject: { }
            )
            .modelContainer(preview.modelContainer),
            width: 1100,
            height: 420
        )
        ViewRenderTestSupport.assertRenders(
            ProjectDetailSummaryRow(viewModel: viewModel),
            width: 1100,
            height: 280
        )
        ViewRenderTestSupport.assertRenders(
            ProjectDetailBillingCard(viewModel: viewModel)
                .modelContainer(preview.modelContainer),
            width: 1100,
            height: 320
        )
        ViewRenderTestSupport.assertRenders(
            ProjectDetailTasksCard(
                viewModel: viewModel,
                onStartTask: { _ in },
                onStop: { }
            )
            .modelContainer(preview.modelContainer),
            width: 1100,
            height: 420
        )
        ViewRenderTestSupport.assertRenders(
            ProjectDetailSessionsCard(
                viewModel: viewModel,
                onAddManualEntry: { },
                onEditSession: { _ in }
            )
            .modelContainer(preview.modelContainer),
            width: 1100,
            height: 420
        )
        ViewRenderTestSupport.assertRenders(
            ProjectDetailBudgetSheet(viewModel: viewModel)
                .modelContainer(preview.modelContainer),
            width: 760,
            height: 520
        )
        ViewRenderTestSupport.assertRenders(
            ProjectDetailExportSheet(viewModel: viewModel)
                .modelContainer(preview.modelContainer),
            width: 560,
            height: 320
        )
        ViewRenderTestSupport.assertRenders(
            ProjectDetailPreviewFactory.makeView(),
            width: 1200,
            height: 1600
        )
    }

    @Test("Creation and manual session sheets render")
    func sheetViewsRender() throws {
        let preview = PreviewWorkspaceSnapshot()
        let project = try #require(preview.projects.first)
        let endedSession = try #require(project.sortedSessions.first(where: { !$0.isActive }))

        ViewRenderTestSupport.assertRenders(
            NewProjectSheet(initialClientName: project.displayClientName) { _ in true },
            width: 520,
            height: 700
        )
        ViewRenderTestSupport.assertRenders(
            ManualSessionSheet(project: project) { _, _, _ in true },
            width: 520,
            height: 620
        )
        ViewRenderTestSupport.assertRenders(
            ManualSessionSheet(
                project: project,
                sessionToEdit: endedSession
            ) { _, _, _ in true },
            width: 520,
            height: 620
        )
    }
}

@MainActor
private enum ViewRenderTestSupport {
    static func assertRenders<V: View>(
        _ view: V,
        width: CGFloat,
        height: CGFloat
    ) {
        let host = ViewRenderHost(
            width: width,
            height: height,
            content: view
        )

#if os(macOS)
        let hostingView = NSHostingView(rootView: host)
        hostingView.frame = CGRect(x: 0, y: 0, width: width, height: height)
        hostingView.layoutSubtreeIfNeeded()
        #expect(hostingView.fittingSize.width.isFinite)
#elseif os(iOS)
        let hostingController = UIHostingController(rootView: host)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: width, height: height)
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
        #expect(hostingController.view.bounds.width == width)
#endif
    }
}

private struct ViewRenderHost<Content: View>: View {
    let width: CGFloat
    let height: CGFloat
    let content: Content

    var body: some View {
        content
            .frame(width: width, height: height, alignment: .topLeading)
    }
}

private enum TargetMembershipError: Error {
    case patternNotFound(String)
}
