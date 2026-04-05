import Foundation
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
}
