import Foundation
import CoreGraphics
import SwiftUI
import Testing
@testable import TimeTracker

@Suite("Model and Formatting")
struct ModelAndFormattingTests {
    @Test("TimeFormatting returns expected digital and compact durations")
    func durationFormatting() {
        #expect(TimeFormatting.digitalDuration(3661) == "01:01:01")
        #expect(TimeFormatting.compactDuration(59 * 60) == "59m")
        #expect(TimeFormatting.compactDuration(3600) == "1h")
        #expect(TimeFormatting.compactDuration(3720) == "1h 2m")
        #expect(TimeFormatting.menuBarDuration(3720) == "1:02")
    }

    @Test("TimeFormatting parses decimal input for German and normalized formats")
    func decimalParsing() {
        #expect(TimeFormatting.parseDecimalInput("95,5") == 95.5)
        #expect(TimeFormatting.parseDecimalInput("95.5") == 95.5)
        #expect(TimeFormatting.parseDecimalInput("1.000") == 1000)
        #expect(TimeFormatting.parseDecimalInput("1,000") == 1000)
        #expect(TimeFormatting.parseDecimalInput("") == nil)
        #expect(TimeFormatting.parseDecimalInput("abc") == nil)
    }

    @Test("TimeFormatting emits euro strings and decimal input")
    func monetaryFormatting() {
        let amountText = TimeFormatting.euroAmount(123.45)
        #expect(amountText.contains("€"))

        let decimalText = TimeFormatting.decimalInput(123.45)
        #expect(TimeFormatting.parseDecimalInput(decimalText) == 123.45)
        #expect(TimeFormatting.decimalInput(nil) == "")
    }

    @Test("TimeFormatting short date and time produce readable output")
    func shortDateAndTimeFormatting() {
        let date = Date(timeIntervalSince1970: 1_704_067_200) // 1 Jan 2024

        #expect(TimeFormatting.shortDate(date).isEmpty == false)
        #expect(TimeFormatting.shortTime(date).isEmpty == false)
    }

    @Test("ClientProject computed properties and sorting are stable")
    func projectComputedProperties() {
        let project = ClientProject(
            clientName: "  Kunde X ",
            name: "  Projekt A ",
            notes: "",
            hourlyRate: 120
        )

        let sessionOld = WorkSession(
            project: project,
            startedAt: Date(timeIntervalSince1970: 10),
            endedAt: Date(timeIntervalSince1970: 20)
        )
        let sessionNew = WorkSession(
            project: project,
            startedAt: Date(timeIntervalSince1970: 30),
            endedAt: Date(timeIntervalSince1970: 40)
        )
        project.sessions = [sessionOld, sessionNew]

        let taskAOld = ProjectTask(
            title: "alpha",
            project: project,
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let taskANew = ProjectTask(
            title: "alpha",
            project: project,
            createdAt: Date(timeIntervalSince1970: 2)
        )
        let taskB = ProjectTask(
            title: "beta",
            project: project,
            createdAt: Date(timeIntervalSince1970: 0)
        )
        project.tasks = [taskB, taskANew, taskAOld]

        #expect(project.displayClientName == "Kunde X")
        #expect(project.displayName == "Projekt A")
        #expect(project.sortedSessions.map(\.id) == [sessionNew.id, sessionOld.id])
        #expect(project.sortedTasks.map(\.id) == [taskAOld.id, taskANew.id, taskB.id])
        #expect(project.hasHourlyRate)
        #expect(project.effectiveHourlyRate == 120)
        #expect(project.billedAmount(for: 1800) == 60)
    }

    @Test("Fallback labels work for empty values")
    func fallbackLabels() {
        let project = ClientProject(clientName: "   ", name: "   ")
        let task = ProjectTask(title: "   ", project: project)
        let session = WorkSession(project: project, task: nil)

        #expect(project.displayClientName == "Ohne Kunde")
        #expect(project.displayName == "Unbenanntes Projekt")
        #expect(task.displayTitle == "Unbenannte Aufgabe")
        #expect(session.displayTaskTitle == "Ohne Aufgabe")
    }

    @Test("ClientProject archive and billing helpers cover edge cases")
    func projectArchiveAndBillingEdgeCases() {
        let projectWithoutRate = ClientProject(clientName: "A", name: "B")
        #expect(projectWithoutRate.isArchived == false)
        #expect(projectWithoutRate.billedAmount(for: 3600) == nil)

        let archivedProject = ClientProject(
            clientName: "A",
            name: "B",
            hourlyRate: -80,
            archivedAt: Date(timeIntervalSince1970: 42)
        )
        #expect(archivedProject.isArchived)
        #expect(archivedProject.effectiveHourlyRate == 0)
        #expect(archivedProject.billedAmount(for: -120) == 0)
    }

    @Test("ClientProject budget helpers support hours and euro targets")
    func projectBudgetHelpers() {
        let project = ClientProject(
            clientName: "A",
            name: "B",
            hourlyRate: 150
        )

        #expect(project.hasBudget == false)
        #expect(project.budgetUnit == nil)
        #expect(project.effectiveBudgetTarget == nil)

        project.setBudget(unit: .hours, target: 12)
        #expect(project.hasBudget)
        #expect(project.budgetUnit == .hours)
        #expect(project.budgetUnitRaw == ProjectBudgetUnit.hours.rawValue)
        #expect(project.effectiveBudgetTarget == 12)
        #expect(project.budgetConsumedValue(for: 3 * 3600) == 3)
        #expect(project.budgetRemainingValue(for: 3 * 3600) == 9)
        #expect(project.budgetProgressFraction(for: 3 * 3600) == 0.25)
        #expect(project.budgetTargetValue(in: .hours) == 12)
        #expect(project.budgetTargetValue(in: .amount) == 1800)
        #expect(project.convertedBudgetValue(20, from: .hours, to: .amount) == 3000)

        project.setBudget(unit: .amount, target: 900)
        #expect(project.budgetUnit == .amount)
        #expect(project.budgetConsumedValue(for: 2 * 3600) == 300)
        #expect(project.budgetRemainingValue(for: 2 * 3600) == 600)
        #expect(project.budgetProgressFraction(for: 8 * 3600) == (1200.0 / 900.0))
        #expect(project.budgetTargetValue(in: .amount) == 900)
        #expect(project.budgetTargetValue(in: .hours) == 6)
        #expect(project.convertedBudgetValue(3000, from: .amount, to: .hours) == 20)

        project.hourlyRate = nil
        #expect(project.budgetConsumedValue(for: 3600) == nil)
        #expect(project.budgetRemainingValue(for: 3600) == nil)
        #expect(project.budgetProgressFraction(for: 3600) == nil)
        #expect(project.budgetTargetValue(in: .hours) == nil)
        #expect(project.convertedBudgetValue(20, from: .hours, to: .amount) == nil)

        project.setBudget(unit: .hours, target: 0)
        #expect(project.hasBudget == false)
        #expect(project.budgetUnit == nil)
        #expect(project.budgetUnitRaw == nil)
        #expect(project.effectiveBudgetTarget == nil)
    }

    @Test("ClientProject allows custom accent color and reset to automatic")
    func projectAccentColorCustomization() {
        let project = ClientProject(clientName: "A", name: "B")

        #expect(project.hasCustomAccentColor == false)

        project.setCustomAccentColor(.red)
        #expect(project.hasCustomAccentColor)
        #expect(project.accentRed != nil)
        #expect(project.accentGreen != nil)
        #expect(project.accentBlue != nil)

        project.clearCustomAccentColor()
        #expect(project.hasCustomAccentColor == false)
        #expect(project.accentRed == nil)
        #expect(project.accentGreen == nil)
        #expect(project.accentBlue == nil)
    }

    @Test("WorkSession duration helpers reflect active and ended states")
    func workSessionDurationHelpers() {
        let project = ClientProject(clientName: "A", name: "B")
        let start = Date(timeIntervalSince1970: 100)
        let activeSession = WorkSession(project: project, startedAt: start)

        #expect(activeSession.isActive)
        #expect(activeSession.duration(referenceDate: Date(timeIntervalSince1970: 160)) == 60)

        activeSession.endedAt = Date(timeIntervalSince1970: 130)
        #expect(activeSession.isActive == false)
        #expect(activeSession.duration(referenceDate: Date(timeIntervalSince1970: 200)) == 30)
        #expect(activeSession.recordedDuration == 30)

        activeSession.endedAt = Date(timeIntervalSince1970: 90)
        #expect(activeSession.duration(referenceDate: Date(timeIntervalSince1970: 200)) == 0)
    }

    @Test("TrackingManagerError provides localized descriptions for all cases")
    func trackingManagerErrorDescriptions() {
        let allErrors: [TrackingManagerError] = [
            .invalidDateRange,
            .futureDateNotAllowed,
            .activeSessionEditingNotAllowed,
            .archivedProjectNotEditable,
            .invalidTaskAssignment,
        ]

        for error in allErrors {
            #expect(error.errorDescription?.isEmpty == false)
        }
    }

    @Test("Project export document groups tasks, durations, and optional costs")
    func projectExportDocumentGeneration() {
        let project = ClientProject(
            clientName: "Export Kunde",
            name: "Export Projekt",
            hourlyRate: 100
        )
        let task = ProjectTask(
            title: "Entwicklung",
            project: project,
            createdAt: Date(timeIntervalSince1970: 1)
        )
        project.tasks = [task]

        let firstSession = WorkSession(
            project: project,
            task: task,
            startedAt: Date(timeIntervalSince1970: 10),
            endedAt: Date(timeIntervalSince1970: 3_610)
        )
        let secondSession = WorkSession(
            project: project,
            task: nil,
            startedAt: Date(timeIntervalSince1970: 5_000),
            endedAt: Date(timeIntervalSince1970: 6_800)
        )
        project.sessions = [secondSession, firstSession]

        let hoursOnlyDocument = ProjectExportService.makeDocument(
            for: project,
            mode: .hoursOnly,
            referenceDate: Date(timeIntervalSince1970: 7_000)
        )

        #expect(hoursOnlyDocument.mode == .hoursOnly)
        #expect(hoursOnlyDocument.totalDuration == 5_400)
        #expect(hoursOnlyDocument.totalCost == nil)
        #expect(hoursOnlyDocument.taskSummaries.count == 2)
        #expect(hoursOnlyDocument.sessionRows.count == 2)

        let costDocument = ProjectExportService.makeDocument(
            for: project,
            mode: .hoursAndCosts,
            referenceDate: Date(timeIntervalSince1970: 7_000)
        )

        #expect(costDocument.mode == .hoursAndCosts)
        #expect(costDocument.totalCost == 150)

        let csvWithCosts = ProjectExportService.csvString(from: costDocument)
        #expect(csvWithCosts.localizedStandardContains("Kosten (EUR)"))
        #expect(csvWithCosts.localizedStandardContains("Entwicklung"))
        #expect(csvWithCosts.localizedStandardContains("Ohne Aufgabe"))

        project.hourlyRate = nil

        let fallbackDocument = ProjectExportService.makeDocument(
            for: project,
            mode: .hoursAndCosts,
            referenceDate: Date(timeIntervalSince1970: 7_000)
        )

        #expect(fallbackDocument.mode == .hoursOnly)

        let csvWithoutCosts = ProjectExportService.csvString(from: fallbackDocument)
        #expect(csvWithoutCosts.localizedStandardContains("Kosten (EUR)") == false)
    }

    @Test("Project export creates a PDF payload")
    func projectExportPDFPayload() throws {
        let project = ClientProject(
            clientName: "Export Kunde",
            name: "Export Projekt",
            hourlyRate: 120
        )
        let task = ProjectTask(title: "QA", project: project)
        project.tasks = [task]
        project.sessions = [
            WorkSession(
                project: project,
                task: task,
                startedAt: Date(timeIntervalSince1970: 100),
                endedAt: Date(timeIntervalSince1970: 1_900)
            ),
        ]

        let document = ProjectExportService.makeDocument(
            for: project,
            mode: .hoursAndCosts,
            referenceDate: Date(timeIntervalSince1970: 2_000)
        )

        let pdfData = ProjectExportService.pdfData(from: document)
        #expect(pdfData.isEmpty == false)

        let headerData = try #require(
            String(data: pdfData.prefix(5), encoding: .ascii)
        )
        #expect(headerData == "%PDF-")
    }

    @Test("Project export PDF keeps text upright")
    func projectExportPDFUprightTextTransform() throws {
        let project = ClientProject(
            clientName: "Export Kunde",
            name: "Export Projekt",
            hourlyRate: 120
        )
        project.sessions = [
            WorkSession(
                project: project,
                startedAt: Date(timeIntervalSince1970: 100),
                endedAt: Date(timeIntervalSince1970: 1_900)
            ),
        ]

        let document = ProjectExportService.makeDocument(
            for: project,
            mode: .hoursAndCosts,
            referenceDate: Date(timeIntervalSince1970: 2_000)
        )

        let pdfData = ProjectExportService.pdfData(from: document)
        let contentStreamText = try #require(pdfContentStreamText(from: pdfData))
        let yScales = matrixYScaleValues(from: contentStreamText)

        #expect(yScales.contains(where: { $0 < 0 }) == false)
    }

    @Test("Project export file naming sanitizes invalid characters")
    func projectExportFileNameSanitizing() {
        #expect(ProjectExportFileNaming.sanitizedFileNameComponent("A/B:C") == "A-B-C")
        #expect(ProjectExportFileNaming.sanitizedFileNameComponent("   ") == "Projekt")
        #expect(ProjectExportFileNaming.sanitizedFileNameComponent("/:*?\"<>|") == "Projekt")
    }

    @Test("Project export file naming uses date stamp and extension")
    func projectExportDefaultFileName() {
        let date = Date(timeIntervalSince1970: 1_704_067_200) // 1 Jan 2024
        let csvName = ProjectExportFileNaming.defaultFileName(
            projectName: "Projekt A",
            format: .csv,
            date: date
        )
        let pdfName = ProjectExportFileNaming.defaultFileName(
            projectName: "Projekt A",
            format: .pdf,
            date: date
        )

        #expect(csvName == "Projekt A-Export-2024-01-01.csv")
        #expect(pdfName == "Projekt A-Export-2024-01-01.pdf")
    }

    @Test("Project detail layout metrics adapt to compact and accessibility sizes")
    func projectDetailLayoutMetrics() {
        #expect(ProjectDetailLayoutMetrics.contentPadding(horizontalSizeClass: .compact) == 16)
        #expect(ProjectDetailLayoutMetrics.contentPadding(horizontalSizeClass: .regular) == 24)

        #expect(ProjectDetailLayoutMetrics.sectionPadding(horizontalSizeClass: .compact) == 16)
        #expect(ProjectDetailLayoutMetrics.sectionPadding(horizontalSizeClass: .regular) == 24)

        #expect(ProjectDetailLayoutMetrics.summaryGridMinimum(horizontalSizeClass: .compact) == 140)
        #expect(ProjectDetailLayoutMetrics.summaryGridMinimum(horizontalSizeClass: .regular) == 180)

        #expect(
            ProjectDetailLayoutMetrics.usesStackedRow(
                dynamicTypeSize: .large,
                horizontalSizeClass: .compact
            )
        )
        #expect(
            ProjectDetailLayoutMetrics.usesStackedRow(
                dynamicTypeSize: .accessibility1,
                horizontalSizeClass: .regular
            )
        )
        #expect(
            ProjectDetailLayoutMetrics.usesStackedRow(
                dynamicTypeSize: .large,
                horizontalSizeClass: .regular
            ) == false
        )

        #expect(
            ProjectDetailLayoutMetrics.sessionRowSpacing(
                dynamicTypeSize: .large,
                horizontalSizeClass: .compact
            ) == 10
        )
        #expect(
            ProjectDetailLayoutMetrics.sessionRowSpacing(
                dynamicTypeSize: .large,
                horizontalSizeClass: .regular
            ) == 12
        )
        #expect(
            ProjectDetailLayoutMetrics.sessionRowSpacing(
                dynamicTypeSize: .accessibility1,
                horizontalSizeClass: .regular
            ) == 10
        )

        #expect(
            ProjectDetailLayoutMetrics.sessionRowPadding(
                dynamicTypeSize: .large,
                horizontalSizeClass: .compact
            ) == 12
        )
        #expect(
            ProjectDetailLayoutMetrics.sessionRowPadding(
                dynamicTypeSize: .large,
                horizontalSizeClass: .regular
            ) == 18
        )
        #expect(
            ProjectDetailLayoutMetrics.sessionRowPadding(
                dynamicTypeSize: .accessibility1,
                horizontalSizeClass: .regular
            ) == 12
        )
    }

    @Test("Workspace layout rules use native tabs only for compact root navigation")
    func workspaceLayoutRules() {
        #expect(
            WorkspaceRootLayoutRules.usesTabRoot(
                horizontalSizeClass: .compact,
                forcedWorkspaceSection: nil,
                prefersNativeTabBar: true
            )
        )
        #expect(
            WorkspaceRootLayoutRules.usesTabRoot(
                horizontalSizeClass: .regular,
                forcedWorkspaceSection: nil,
                prefersNativeTabBar: true
            ) == false
        )
        #expect(
            WorkspaceRootLayoutRules.usesTabRoot(
                horizontalSizeClass: .compact,
                forcedWorkspaceSection: .analytics,
                prefersNativeTabBar: true
            ) == false
        )
        #expect(
            WorkspaceRootLayoutRules.usesTabRoot(
                horizontalSizeClass: .compact,
                forcedWorkspaceSection: nil,
                prefersNativeTabBar: false
            ) == false
        )
    }

    @Test("Project export selection normalizes mode without hourly rate")
    func projectExportSelectionNormalization() {
        let normalizedWithoutRate = ProjectExportSelection.current(
            format: .pdf,
            selectedMode: .hoursAndCosts,
            hasHourlyRate: false
        )
        #expect(normalizedWithoutRate == ProjectExportSelection(format: .pdf, mode: .hoursOnly))

        let withRate = ProjectExportSelection.current(
            format: .csv,
            selectedMode: .hoursAndCosts,
            hasHourlyRate: true
        )
        #expect(withRate == ProjectExportSelection(format: .csv, mode: .hoursAndCosts))

        #expect(normalizedWithoutRate != withRate)
    }

    private func pdfContentStreamText(from pdfData: Data) -> String? {
        guard let provider = CGDataProvider(data: pdfData as CFData),
              let pdfDocument = CGPDFDocument(provider),
              let firstPage = pdfDocument.page(at: 1) else {
            return nil
        }

        guard let pageDictionary = firstPage.dictionary else {
            return nil
        }
        let streamData = contentStreamData(from: pageDictionary)

        guard !streamData.isEmpty else {
            return nil
        }

        return String(data: streamData, encoding: .ascii)
    }

    private func contentStreamData(from pageDictionary: CGPDFDictionaryRef) -> Data {
        var streamData = Data()
        var directStream: CGPDFStreamRef?

        let hasDirectStream = "Contents".withCString { key in
            CGPDFDictionaryGetStream(pageDictionary, key, &directStream)
        }

        if hasDirectStream, let directStream {
            streamData.append(decodedStreamData(from: directStream))
            return streamData
        }

        var streamArray: CGPDFArrayRef?
        let hasStreamArray = "Contents".withCString { key in
            CGPDFDictionaryGetArray(pageDictionary, key, &streamArray)
        }

        guard hasStreamArray, let streamArray else {
            return streamData
        }

        let streamCount = CGPDFArrayGetCount(streamArray)
        for index in 0..<streamCount {
            var stream: CGPDFStreamRef?
            guard CGPDFArrayGetStream(streamArray, index, &stream),
                  let stream else {
                continue
            }

            streamData.append(decodedStreamData(from: stream))
            streamData.append(0x0A)
        }

        return streamData
    }

    private func decodedStreamData(from stream: CGPDFStreamRef) -> Data {
        var dataFormat = CGPDFDataFormat.raw
        guard let rawData = CGPDFStreamCopyData(stream, &dataFormat) as Data? else {
            return Data()
        }

        return rawData
    }

    private func matrixYScaleValues(from contentStreamText: String) -> [Double] {
        let tokens = contentStreamText
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        guard tokens.count >= 7 else {
            return []
        }

        var yScaleValues: [Double] = []
        for index in 6..<tokens.count where tokens[index] == "cm" {
            let dToken = tokens[index - 3]
            if let yScale = Double(dToken) {
                yScaleValues.append(yScale)
            }
        }

        return yScaleValues
    }
}
