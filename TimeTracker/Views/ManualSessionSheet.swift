import SwiftUI

struct ManualSessionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let project: ClientProject
    let sessionToEdit: WorkSession?
    let onSave: (Date, Date, ProjectTask?) -> Bool

    @State private var startedAt: Date
    @State private var endedAt: Date
    @State private var selectedTaskID: UUID?
    @State private var validationMessage: String?

    init(
        project: ClientProject,
        sessionToEdit: WorkSession? = nil,
        onSave: @escaping (Date, Date, ProjectTask?) -> Bool
    ) {
        self.project = project
        self.sessionToEdit = sessionToEdit
        self.onSave = onSave

        let initialState = ManualSessionLogic.initialState(
            sessionToEdit: sessionToEdit,
            now: Date(),
            calendar: .current
        )

        _startedAt = State(initialValue: initialState.startedAt)
        _endedAt = State(initialValue: initialState.endedAt)
        _selectedTaskID = State(initialValue: initialState.selectedTaskID)
    }

    private var durationText: String {
        ManualSessionLogic.durationText(
            startedAt: startedAt,
            endedAt: endedAt
        )
    }

    private var titleText: String {
        ManualSessionLogic.titleText(isEditing: sessionToEdit != nil)
    }

    private var submitButtonTitle: String {
        ManualSessionLogic.submitButtonTitle(isEditing: sessionToEdit != nil)
    }

    private var availableTasks: [ProjectTask] {
        project.sortedTasks
    }

    private var selectedTask: ProjectTask? {
        ManualSessionLogic.selectedTask(
            tasks: availableTasks,
            selectedTaskID: selectedTaskID
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(titleText)
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text("\(project.displayClientName) - \(project.displayName)")
                .foregroundStyle(.secondary)

            Form {
                DatePicker(
                    "Start",
                    selection: $startedAt,
                    in: ...Date(),
                    displayedComponents: [.date, .hourAndMinute]
                )

                DatePicker(
                    "Ende",
                    selection: $endedAt,
                    in: startedAt...Date(),
                    displayedComponents: [.date, .hourAndMinute]
                )

                if !availableTasks.isEmpty {
                    Picker("Aufgabe", selection: $selectedTaskID) {
                        Text("Ohne Aufgabe")
                            .tag(Optional<UUID>.none)

                        ForEach(availableTasks) { task in
                            Text(task.displayTitle)
                                .tag(Optional(task.id))
                        }
                    }
                }

                LabeledContent("Dauer") {
                    Text(durationText)
                        .monospacedDigit()
                }
            }
            .formStyle(.grouped)

            if let validationMessage {
                Text(validationMessage)
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()

                Button("Abbrechen", role: .cancel) {
                    dismiss()
                }

                Button(submitButtonTitle) {
                    validationMessage = nil

                    if let message = ManualSessionLogic.validationMessage(
                        startedAt: startedAt,
                        endedAt: endedAt,
                        now: Date()
                    ) {
                        validationMessage = message
                        return
                    }

                    if onSave(startedAt, endedAt, selectedTask) {
                        dismiss()
                    } else {
                        validationMessage = "Der Zeiteintrag konnte nicht gespeichert werden."
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(ClientProject.primaryActionColor)
            }
        }
        .padding(24)
#if os(macOS)
        .frame(width: 460)
#else
        .frame(maxWidth: .infinity, alignment: .leading)
#endif
    }
}

enum ManualSessionLogic {
    static func initialState(
        sessionToEdit: WorkSession?,
        now: Date,
        calendar: Calendar
    ) -> (startedAt: Date, endedAt: Date, selectedTaskID: UUID?) {
        let roundedEnd = calendar.dateInterval(
            of: .minute,
            for: now
        )?.start ?? now
        let roundedStart = calendar.date(
            byAdding: .hour,
            value: -1,
            to: roundedEnd
        ) ?? roundedEnd.addingTimeInterval(-3600)

        return (
            startedAt: sessionToEdit?.startedAt ?? roundedStart,
            endedAt: sessionToEdit?.endedAt ?? roundedEnd,
            selectedTaskID: sessionToEdit?.task?.id
        )
    }

    static func durationText(
        startedAt: Date,
        endedAt: Date
    ) -> String {
        TimeFormatting.digitalDuration(
            max(endedAt.timeIntervalSince(startedAt), 0)
        )
    }

    static func titleText(isEditing: Bool) -> String {
        isEditing ? "Zeiteintrag bearbeiten" : "Zeiteintrag nachtragen"
    }

    static func submitButtonTitle(isEditing: Bool) -> String {
        isEditing ? "Aenderungen speichern" : "Eintrag speichern"
    }

    static func selectedTask(
        tasks: [ProjectTask],
        selectedTaskID: UUID?
    ) -> ProjectTask? {
        guard let selectedTaskID else {
            return nil
        }

        return tasks.first { $0.id == selectedTaskID }
    }

    static func validationMessage(
        startedAt: Date,
        endedAt: Date,
        now: Date
    ) -> String? {
        guard endedAt > startedAt else {
            return "Das Enddatum muss nach dem Startdatum liegen."
        }

        guard startedAt <= now, endedAt <= now else {
            return "Nachgetragene Zeiteintraege duerfen nicht in der Zukunft liegen."
        }

        return nil
    }
}

#Preview("Manual session sheet") {
    let project = ClientProject.sampleData[0]

    return NavigationStack {
        ManualSessionSheet(project: project) { _, _, _ in true }
    }
    .frame(width: 520, height: 560)
}

#Preview("Manual session edit") {
    let project = ClientProject.sampleData[0]
    let session = project.sessionList.first(where: \.isActive) ?? project.sessionList[0]

    return NavigationStack {
        ManualSessionSheet(
            project: project,
            sessionToEdit: session
        ) { _, _, _ in true }
    }
    .frame(width: 520, height: 560)
}
