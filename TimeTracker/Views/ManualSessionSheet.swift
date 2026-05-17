import SwiftUI

struct ManualSessionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let project: ClientProject
    let sessionToEdit: WorkSession?
    let fixedTask: ProjectTask?
    let onSave: (Date, Date, ProjectTask?) -> Bool

    @State private var startedAt: Date
    @State private var endedAt: Date
    @State private var selectedTaskID: UUID?
    @State private var validationMessage: String?

    init(
        project: ClientProject,
        sessionToEdit: WorkSession? = nil,
        fixedTask: ProjectTask? = nil,
        onSave: @escaping (Date, Date, ProjectTask?) -> Bool
    ) {
        self.project = project
        self.sessionToEdit = sessionToEdit
        self.fixedTask = fixedTask
        self.onSave = onSave

        let initialState = ManualSessionLogic.initialState(
            sessionToEdit: sessionToEdit,
            fixedTask: fixedTask,
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
            selectedTaskID: selectedTaskID,
            fixedTask: fixedTask
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

                if let fixedTask {
                    LabeledContent("Aufgabe") {
                        Text(fixedTask.displayTitle)
                    }
                } else if !availableTasks.isEmpty {
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

struct TaskEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let task: ProjectTask
    let onSaveTaskTitle: (String) -> Bool
    let onAddEntry: (Date, Date) -> Bool
    let onUpdateEntry: (WorkSession, Date, Date) -> Bool
    let onDeleteTask: (ProjectTask) -> Bool
    let onDeleteEntry: (WorkSession) -> Bool

    @State private var title: String
    @State private var validationMessage: String?
    @State private var isPresentingManualEntrySheet = false
    @State private var sessionToEdit: WorkSession?
    @State private var pendingTaskDeletion: ProjectTask?
    @State private var pendingSessionDeletion: WorkSession?

    init(
        task: ProjectTask,
        onSaveTaskTitle: @escaping (String) -> Bool,
        onAddEntry: @escaping (Date, Date) -> Bool,
        onUpdateEntry: @escaping (WorkSession, Date, Date) -> Bool,
        onDeleteTask: @escaping (ProjectTask) -> Bool,
        onDeleteEntry: @escaping (WorkSession) -> Bool
    ) {
        self.task = task
        self.onSaveTaskTitle = onSaveTaskTitle
        self.onAddEntry = onAddEntry
        self.onUpdateEntry = onUpdateEntry
        self.onDeleteTask = onDeleteTask
        self.onDeleteEntry = onDeleteEntry
        _title = State(initialValue: ProjectDetailLogic.normalizedTaskTitle(task.title))
    }

    private var deleteTaskAlertBinding: Binding<Bool> {
        Binding(
            get: { pendingTaskDeletion != nil },
            set: { isPresented in
                pendingTaskDeletion = ProjectDetailLogic.pendingTaskAfterDeletionPresentationChange(
                    currentTask: pendingTaskDeletion,
                    isPresented: isPresented
                )
            }
        )
    }

    private var editEntrySheetBinding: Binding<Bool> {
        Binding(
            get: { sessionToEdit != nil },
            set: { isPresented in
                sessionToEdit = ProjectDetailLogic.pendingSessionAfterEditorPresentationChange(
                    currentSession: sessionToEdit,
                    isPresented: isPresented
                )
            }
        )
    }

    private var deleteEntryAlertBinding: Binding<Bool> {
        Binding(
            get: { pendingSessionDeletion != nil },
            set: { isPresented in
                pendingSessionDeletion = ProjectDetailLogic.pendingSessionAfterDeletionPresentationChange(
                    currentSession: pendingSessionDeletion,
                    isPresented: isPresented
                )
            }
        )
    }

    var body: some View {
        let project = task.project
        let taskSessions = ProjectDetailLogic.taskEditorSessions(for: task)

        VStack(alignment: .leading, spacing: 20) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Aufgabe bearbeiten")
                        .font(.title2)
                        .bold()

                    VStack(alignment: .leading, spacing: 6) {
                        Text(project?.displayClientName ?? "Ohne Kunde")
                            .font(.headline)

                        Text(project?.displayName ?? "Unbenanntes Projekt")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    TextField("Aufgabentitel", text: $title)
                        .textFieldStyle(.roundedBorder)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .center) {
                            Text("Eintraege")
                                .font(.headline)

                            Spacer()

                            Button("Eintrag hinzufuegen", systemImage: "plus") {
                                validationMessage = nil
                                isPresentingManualEntrySheet = true
                            }
                            .disabled(project == nil || project?.isArchived == true)
                        }

                        if taskSessions.isEmpty {
                            Text("Noch keine Eintraege fuer diese Aufgabe.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(taskSessions) { session in
                                    SessionRow(
                                        session: session,
                                        hourlyRate: project?.hourlyRate,
                                        availableTasks: [],
                                        onAssignToTask: nil,
                                        onCreateTaskAndAssign: nil,
                                        onEdit: {
                                            validationMessage = nil
                                            sessionToEdit = session
                                        },
                                        onDelete: {
                                            validationMessage = nil
                                            pendingSessionDeletion = session
                                        }
                                    )
                                }
                            }
                        }
                    }

                    if let validationMessage {
                        Text(validationMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }

                    Divider()

                    Button("Aufgabe loeschen", role: .destructive) {
                        validationMessage = nil
                        pendingTaskDeletion = task
                    }
                }
            }

            HStack {
                Spacer()

                Button("Abbrechen", role: .cancel) {
                    dismiss()
                }

                Button("Speichern") {
                    let normalizedTitle = ProjectDetailLogic.normalizedTaskTitle(title)

                    if let validationMessage = ProjectDetailLogic.taskTitleValidationMessage(normalizedTitle) {
                        self.validationMessage = validationMessage
                        return
                    }

                    self.validationMessage = nil

                    if onSaveTaskTitle(normalizedTitle) {
                        dismiss()
                    } else {
                        self.validationMessage = "Die Aufgabe konnte nicht gespeichert werden."
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(project?.projectAccentColor ?? ClientProject.primaryActionColor)
                .disabled(ProjectDetailLogic.normalizedTaskTitle(title).isEmpty)
            }
        }
        .padding(24)
        .sheet(isPresented: $isPresentingManualEntrySheet) {
            if let project {
                NavigationStack {
                    ManualSessionSheet(
                        project: project,
                        fixedTask: task,
                        onSave: { startedAt, endedAt, _ in
                            let didSave = onAddEntry(startedAt, endedAt)

                            if didSave {
                                validationMessage = nil
                            } else {
                                validationMessage = ProjectDetailLogic.taskEditorEntrySaveErrorMessage(isEditing: false)
                            }

                            return didSave
                        }
                    )
                }
            }
        }
        .sheet(isPresented: editEntrySheetBinding) {
            if let project, let sessionToEdit {
                NavigationStack {
                    ManualSessionSheet(
                        project: project,
                        sessionToEdit: sessionToEdit,
                        fixedTask: task,
                        onSave: { startedAt, endedAt, _ in
                            let didSave = onUpdateEntry(sessionToEdit, startedAt, endedAt)

                            if didSave {
                                validationMessage = nil
                            } else {
                                validationMessage = ProjectDetailLogic.taskEditorEntrySaveErrorMessage(isEditing: true)
                            }

                            return didSave
                        }
                    )
                }
            }
        }
        .alert(
            "Aufgabe entfernen?",
            isPresented: deleteTaskAlertBinding,
            presenting: pendingTaskDeletion
        ) { task in
            Button("Entfernen", role: .destructive) {
                let didDelete = onDeleteTask(task)

                if didDelete {
                    validationMessage = nil
                    pendingTaskDeletion = nil
                    dismiss()
                } else {
                    validationMessage = ProjectDetailLogic.taskEditorTaskDeleteErrorMessage()
                }
            }

            Button("Abbrechen", role: .cancel) {
                pendingTaskDeletion = nil
            }
        } message: { task in
            Text("Die Aufgabe \(task.displayTitle) und alle zugeordneten Eintraege werden entfernt.")
        }
        .alert(
            "Eintrag entfernen?",
            isPresented: deleteEntryAlertBinding,
            presenting: pendingSessionDeletion
        ) { session in
            Button("Entfernen", role: .destructive) {
                let didDelete = onDeleteEntry(session)

                if didDelete {
                    validationMessage = nil
                    pendingSessionDeletion = nil
                } else {
                    validationMessage = "Der Zeiteintrag konnte nicht entfernt werden."
                }
            }

            Button("Abbrechen", role: .cancel) {
                pendingSessionDeletion = nil
            }
        } message: { session in
            Text(
                "Der Eintrag vom \(TimeFormatting.shortDate(session.startedAt)) um \(TimeFormatting.shortTime(session.startedAt)) wird entfernt."
            )
        }
#if os(macOS)
        .frame(width: 560, height: 640)
#else
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
#endif
    }
}

enum ManualSessionLogic {
    static func initialState(
        sessionToEdit: WorkSession?,
        fixedTask: ProjectTask? = nil,
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
            selectedTaskID: sessionToEdit?.task?.id ?? fixedTask?.id
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
        selectedTaskID: UUID?,
        fixedTask: ProjectTask? = nil
    ) -> ProjectTask? {
        if let fixedTask {
            return tasks.first { $0.id == fixedTask.id } ?? fixedTask
        }

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

#Preview("Task editor") {
    let project = ClientProject.sampleData[0]
    let task = project.sortedTasks.first ?? ProjectTask(title: "Konzept", project: project)

    return NavigationStack {
        TaskEditorSheet(
            task: task,
            onSaveTaskTitle: { _ in true },
            onAddEntry: { _, _ in true },
            onUpdateEntry: { _, _, _ in true },
            onDeleteTask: { _ in true },
            onDeleteEntry: { _ in true }
        )
    }
    .frame(width: 620, height: 720)
}
