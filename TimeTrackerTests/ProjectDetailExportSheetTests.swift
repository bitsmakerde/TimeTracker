import Foundation
import Testing
import UniformTypeIdentifiers
@testable import TimeTracker

@Suite("Project Detail Export Sheet")
@MainActor
struct ProjectDetailExportSheetTests {
    private func makeViewModel(
        project: ClientProject,
        activeSession: WorkSession? = nil
    ) -> ProjectDetailViewModel {
        ProjectDetailViewModel(project: project, activeSession: activeSession)
    }

    @Test("Export configuration follows hourly rate")
    func exportConfigurationFollowsHourlyRate() {
        let project = ClientProject(clientName: "Acme", name: "Website")
        let vm = makeViewModel(project: project)

        #expect(
            ProjectDetailLogic.normalizedExportContentMode(
                selectedMode: .hoursAndCosts,
                hasHourlyRate: false
            ) == .hoursOnly
        )
        #expect(ProjectDetailLogic.availableExportModes(hasHourlyRate: false) == [.hoursOnly])

        let staleSelection = ProjectExportSelection(format: .pdf, mode: .hoursAndCosts)
        let currentSelection = ProjectDetailLogic.currentExportSelection(
            format: .pdf,
            selectedMode: .hoursAndCosts,
            project: project
        )
        #expect(
            ProjectDetailLogic.hasPreparedExport(
                preparedURL: URL.temporaryDirectory.appending(path: "stale.pdf"),
                preparedSelection: staleSelection,
                currentSelection: currentSelection
            ) == false
        )

        let preparedURL = vm.makePreparedExportURL(for: .csv)
        #expect(preparedURL.pathExtension == "csv")
        #expect(preparedURL.lastPathComponent.localizedStandardContains("Website-Export"))

        project.hourlyRate = 120
        #expect(ProjectDetailLogic.availableExportModes(hasHourlyRate: project.hasHourlyRate) == ProjectExportContentMode.allCases)

#if os(macOS)
        #expect(vm.utType(for: .csv) == .commaSeparatedText)
        #expect(vm.utType(for: .pdf) == .pdf)
#endif
    }
}
