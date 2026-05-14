import Foundation
import Testing
@testable import TimeTracker

@Suite("Manual Session Logic")
struct ManualSessionLogicTests {
    @Test("Initial state rounds new sessions and preserves edited sessions")
    func initialStateRoundingAndEditing() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))

        let now = try #require(
            calendar.date(
                from: DateComponents(
                    timeZone: calendar.timeZone,
                    year: 2026,
                    month: 5,
                    day: 14,
                    hour: 10,
                    minute: 30,
                    second: 45
                )
            )
        )
        let roundedEnd = try #require(
            calendar.date(
                from: DateComponents(
                    timeZone: calendar.timeZone,
                    year: 2026,
                    month: 5,
                    day: 14,
                    hour: 10,
                    minute: 30,
                    second: 0
                )
            )
        )
        let roundedStart = try #require(
            calendar.date(
                from: DateComponents(
                    timeZone: calendar.timeZone,
                    year: 2026,
                    month: 5,
                    day: 14,
                    hour: 9,
                    minute: 30,
                    second: 0
                )
            )
        )

        let newState = ManualSessionLogic.initialState(
            sessionToEdit: nil,
            now: now,
            calendar: calendar
        )

        #expect(newState.startedAt == roundedStart)
        #expect(newState.endedAt == roundedEnd)
        #expect(newState.selectedTaskID == nil)

        let project = ClientProject(clientName: "Acme", name: "Website")
        let task = ProjectTask(title: "Konzept", project: project)
        let existingSession = WorkSession(
            project: project,
            task: task,
            startedAt: now.addingTimeInterval(-7_200),
            endedAt: now.addingTimeInterval(-3_600)
        )

        let editState = ManualSessionLogic.initialState(
            sessionToEdit: existingSession,
            now: now,
            calendar: calendar
        )

        #expect(editState.startedAt == existingSession.startedAt)
        #expect(editState.endedAt == existingSession.endedAt)
        #expect(editState.selectedTaskID == task.id)
    }

    @Test("Manual session labels, task selection, and duration text stay stable")
    func labelsSelectionAndDuration() {
        let project = ClientProject(clientName: "Acme", name: "Website")
        let firstTask = ProjectTask(title: "Alpha", project: project)
        let secondTask = ProjectTask(title: "Beta", project: project)

        #expect(ManualSessionLogic.titleText(isEditing: false) == "Zeiteintrag nachtragen")
        #expect(ManualSessionLogic.titleText(isEditing: true) == "Zeiteintrag bearbeiten")
        #expect(ManualSessionLogic.submitButtonTitle(isEditing: false) == "Eintrag speichern")
        #expect(ManualSessionLogic.submitButtonTitle(isEditing: true) == "Aenderungen speichern")
        #expect(
            ManualSessionLogic.durationText(
                startedAt: Date(timeIntervalSince1970: 100),
                endedAt: Date(timeIntervalSince1970: 3_700)
            ) == "01:00:00"
        )
        #expect(
            ManualSessionLogic.selectedTask(
                tasks: [firstTask, secondTask],
                selectedTaskID: secondTask.id
            )?.id == secondTask.id
        )
        #expect(
            ManualSessionLogic.selectedTask(
                tasks: [firstTask, secondTask],
                selectedTaskID: UUID()
            ) == nil
        )
    }

    @Test("Manual session validation rejects invalid and future ranges")
    func validationMessages() throws {
        let now = Date(timeIntervalSince1970: 10_000)
        let startedAt = now.addingTimeInterval(-3_600)
        let endedAt = now.addingTimeInterval(-1_800)

        #expect(
            ManualSessionLogic.validationMessage(
                startedAt: startedAt,
                endedAt: startedAt,
                now: now
            ) == "Das Enddatum muss nach dem Startdatum liegen."
        )
        #expect(
            ManualSessionLogic.validationMessage(
                startedAt: now.addingTimeInterval(60),
                endedAt: now.addingTimeInterval(120),
                now: now
            ) == "Nachgetragene Zeiteintraege duerfen nicht in der Zukunft liegen."
        )
        #expect(
            ManualSessionLogic.validationMessage(
                startedAt: startedAt,
                endedAt: endedAt,
                now: now
            ) == nil
        )
    }
}
