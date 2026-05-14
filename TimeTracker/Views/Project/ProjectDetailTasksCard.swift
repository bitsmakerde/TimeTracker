import SwiftData
import SwiftUI

struct ProjectDetailTasksCard: View {
    @Bindable var viewModel: ProjectDetailViewModel
    let onStartTask: (ProjectTask) -> Void
    let onStop: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var usesStackedRows: Bool {
        ProjectDetailLayoutMetrics.usesStackedRow(
            dynamicTypeSize: dynamicTypeSize,
            horizontalSizeClass: horizontalSizeClass
        )
    }
    private var sectionPadding: CGFloat { ProjectDetailLayoutMetrics.sectionPadding(horizontalSizeClass: horizontalSizeClass) }
    private var cornerRadius: CGFloat { ProjectDetailLayoutMetrics.sectionCornerRadius(horizontalSizeClass: horizontalSizeClass) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text("Aufgaben").font(.title2).bold()
                    Spacer()
                    Text("\(viewModel.project.taskList.count) gesamt")
                        .font(.subheadline).foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Aufgaben").font(.title2).bold()
                    Text("\(viewModel.project.taskList.count) gesamt")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }

            if !viewModel.project.isArchived {
                taskAddField

                if let selectedTask = viewModel.selectedTaskForStart {
                    Label(
                        "Zeiterfassung startet mit: \(selectedTask.displayTitle)",
                        systemImage: "scope"
                    )
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(viewModel.project.projectAccentColor)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            if viewModel.project.sortedTasks.isEmpty {
                Text(viewModel.project.isArchived
                    ? "Dieses Projekt hat keine Aufgaben."
                    : "Lege Aufgaben an, damit du Zeiten direkt auf Arbeitspakete buchen kannst.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.project.sortedTasks) { task in
                            TaskSummaryRow(
                                title: task.displayTitle,
                                subtitle: "\(viewModel.taskSessionCount(for: task)) Eintraege",
                                durationText: TimeFormatting.compactDuration(
                                    viewModel.taskDuration(for: task, referenceDate: timeline.date)
                                ),
                                valueText: viewModel.taskValueText(for: task, referenceDate: timeline.date),
                                isActive: viewModel.activeSession?.task?.id == task.id,
                                isSelectedForStart: viewModel.selectedTaskForStart?.id == task.id,
                                isProjectRunningWithoutTask: viewModel.isProjectRunningWithoutTask,
                                accentColor: viewModel.project.projectActionColor,
                                isArchived: viewModel.project.isArchived,
                                onSelectForStart: {
                                    viewModel.selectTaskForStart(task, modelContext: modelContext)
                                },
                                onStart: { onStartTask(task) },
                                onStop: onStop
                            )
                        }
                    }
                }
            }
        }
        .padding(sectionPadding)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(ProjectDetailLayoutMetrics.sectionCardGradient(colorScheme: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(ProjectDetailLayoutMetrics.sectionCardStroke(colorScheme: colorScheme), lineWidth: 1)
        )
        .shadow(color: ProjectDetailLayoutMetrics.sectionCardShadow(colorScheme: colorScheme), radius: 14, x: 0, y: 8)
    }

    @ViewBuilder
    private var taskAddField: some View {
        if usesStackedRows {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Neue Aufgabe", text: $viewModel.newTaskTitle)
                    .textFieldStyle(.roundedBorder)

                Button("Aufgabe hinzufuegen") {
                    viewModel.addTask(modelContext: modelContext)
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.project.projectActionColor)
                .disabled(viewModel.trimmedNewTaskTitle.isEmpty)
            }
        } else {
            HStack(alignment: .center, spacing: 12) {
                TextField("Neue Aufgabe", text: $viewModel.newTaskTitle)
                    .textFieldStyle(.roundedBorder)

                Button("Aufgabe hinzufuegen") {
                    viewModel.addTask(modelContext: modelContext)
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.project.projectActionColor)
                .disabled(viewModel.trimmedNewTaskTitle.isEmpty)
            }
        }
    }
}

#Preview {
    let project = ClientProject.sampleData[0]
    let viewModel = ProjectDetailViewModel(project: project, activeSession: nil)
    return ProjectDetailTasksCard(
        viewModel: viewModel,
        onStartTask: { _ in },
        onStop: {}
    )
    .padding()
    .modelContainer(ModelContainer.preview)
}
