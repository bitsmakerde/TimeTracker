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

        let now = Date()
        let roundedEnd = Calendar.current.date(
            bySetting: .second,
            value: 0,
            of: now
        ) ?? now
        let roundedStart = Calendar.current.date(
            byAdding: .hour,
            value: -1,
            to: roundedEnd
        ) ?? roundedEnd.addingTimeInterval(-3600)

        _startedAt = State(initialValue: sessionToEdit?.startedAt ?? roundedStart)
        _endedAt = State(initialValue: sessionToEdit?.endedAt ?? roundedEnd)
        _selectedTaskID = State(initialValue: sessionToEdit?.task?.id)
    }

    private var durationText: String {
        TimeFormatting.digitalDuration(max(endedAt.timeIntervalSince(startedAt), 0))
    }

    private var titleText: String {
        sessionToEdit == nil ? "Zeiteintrag nachtragen" : "Zeiteintrag bearbeiten"
    }

    private var submitButtonTitle: String {
        sessionToEdit == nil ? "Eintrag speichern" : "Aenderungen speichern"
    }

    private var availableTasks: [ProjectTask] {
        project.sortedTasks
    }

    private var selectedTask: ProjectTask? {
        guard let selectedTaskID else {
            return nil
        }

        return availableTasks.first { $0.id == selectedTaskID }
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

                    guard endedAt > startedAt else {
                        validationMessage = "Das Enddatum muss nach dem Startdatum liegen."
                        return
                    }

                    guard startedAt <= Date(), endedAt <= Date() else {
                        validationMessage = "Nachgetragene Zeiteintraege duerfen nicht in der Zukunft liegen."
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
        .frame(width: 460)
    }
}
