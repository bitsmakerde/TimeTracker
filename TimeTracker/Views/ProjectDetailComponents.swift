import SwiftUI
import Charts

struct ProjectBudgetSnapshot {
    let unit: ProjectBudgetUnit
    let target: Double
    let consumed: Double

    var remaining: Double {
        target - consumed
    }

    var progress: Double {
        guard target > 0 else {
            return 0
        }

        return consumed / target
    }

    var isOverBudget: Bool {
        remaining < 0
    }

    var progressText: String {
        progress.formatted(
            .percent
                .precision(.fractionLength(0))
        )
    }

    func statusText(unitFormatter: (Double, ProjectBudgetUnit) -> String) -> String {
        if remaining > 0 {
            return "Restbudget: \(unitFormatter(remaining, unit))"
        }

        if remaining < 0 {
            return "Ueberzogen um \(unitFormatter(abs(remaining), unit))"
        }

        return "Budget exakt erreicht"
    }
}

struct BudgetProgressDonut: View {
    let snapshot: ProjectBudgetSnapshot
    let accentColor: Color

    private var chartSegments: [BudgetProgressSegment] {
        let consumedInTarget = min(max(snapshot.consumed, 0), max(snapshot.target, 0))
        let remaining = max(snapshot.target - consumedInTarget, 0)
        let overBudget = max(snapshot.consumed - snapshot.target, 0)

        var segments: [BudgetProgressSegment] = []

        if consumedInTarget > 0 {
            segments.append(
                BudgetProgressSegment(
                    label: "Verbraucht",
                    value: consumedInTarget,
                    color: accentColor
                )
            )
        }

        if remaining > 0 {
            segments.append(
                BudgetProgressSegment(
                    label: "Rest",
                    value: remaining,
                    color: .secondary.opacity(0.28)
                )
            )
        }

        if overBudget > 0 {
            segments.append(
                BudgetProgressSegment(
                    label: "Ueber Budget",
                    value: overBudget,
                    color: ClientProject.stopActionColor
                )
            )
        }

        if segments.isEmpty {
            return [
                BudgetProgressSegment(
                    label: "Leer",
                    value: 1,
                    color: .secondary.opacity(0.18)
                )
            ]
        }

        return segments
    }

    var body: some View {
        Chart(chartSegments) { segment in
            SectorMark(
                angle: .value("Anteil", segment.value),
                innerRadius: .ratio(0.64),
                angularInset: 1
            )
            .foregroundStyle(segment.color)
        }
        .chartLegend(.hidden)
    }
}

struct BudgetProgressSegment: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let color: Color
}

struct SummaryCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let title: String
    let value: String
    let subtitle: String
    var accessorySystemImage: String? = nil
    var accessoryAction: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(summarySecondaryStyle)

                Spacer(minLength: 0)

                if let accessoryAction {
                    Button(action: accessoryAction) {
                        Image(systemName: accessorySystemImage ?? "gearshape.fill")
                            .font(.footnote)
                            .bold()
                            .foregroundStyle(summarySecondaryStyle)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(value)
                .font(horizontalSizeClass == .compact ? .title2 : .title)
                .bold()
                .monospacedDigit()
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(summarySecondaryStyle)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(horizontalSizeClass == .compact ? 16 : 22)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(summaryCardGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(summaryCardStroke, lineWidth: 1)
        )
        .shadow(color: summaryCardShadow, radius: 10, x: 0, y: 6)
    }

    private var summarySecondaryStyle: Color {
        colorScheme == .dark ? Color.white.opacity(0.66) : Color.black.opacity(0.60)
    }

    private var summaryCardGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [Color.white.opacity(0.07), Color.black.opacity(0.24)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [Color.white.opacity(0.98), Color(red: 0.96, green: 0.97, blue: 0.99)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var summaryCardStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.10)
    }

    private var summaryCardShadow: Color {
        colorScheme == .dark ? Color.black.opacity(0.12) : Color.black.opacity(0.07)
    }
}

struct TaskSummaryRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let title: String
    let subtitle: String
    let durationText: String
    let valueText: String
    let isActive: Bool
    let isSelectedForStart: Bool
    let isProjectRunningWithoutTask: Bool
    let accentColor: Color
    let isArchived: Bool
    let onSelectForStart: () -> Void
    let onStart: () -> Void
    let onStop: () -> Void

    private var shouldShowStop: Bool {
        isActive || (isSelectedForStart && isProjectRunningWithoutTask)
    }

    private var usesStackedLayout: Bool {
        ProjectDetailLayoutMetrics.usesStackedRow(
            dynamicTypeSize: dynamicTypeSize,
            horizontalSizeClass: horizontalSizeClass
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onSelectForStart) {
                if usesStackedLayout {
                    VStack(alignment: .leading, spacing: 10) {
                        taskTitleBlock

                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(rowSecondaryStyle)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: 0)

                            taskMetricBlock(alignment: .trailing)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
                } else {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            taskTitleBlock

                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(rowSecondaryStyle)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        taskMetricBlock(alignment: .trailing)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
                }
            }
            .buttonStyle(.plain)
            .disabled(isArchived)

            if !isArchived {
                Button(action: {
                    if shouldShowStop {
                        onStop()
                    } else {
                        onStart()
                    }
                }) {
                    Label(
                        shouldShowStop ? "Stoppen" : "Starten",
                        systemImage: shouldShowStop ? "stop.fill" : "play.fill"
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.borderedProminent)
                .tint(shouldShowStop ? ClientProject.stopActionColor : accentColor)
            }
        }
        .padding(usesStackedLayout ? 14 : 18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(rowGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    isSelectedForStart ? accentColor.opacity(0.55) : rowStroke,
                    lineWidth: isSelectedForStart ? 1.5 : 1
                )
        )
        .shadow(color: rowShadow, radius: 6, x: 0, y: 3)
    }

    private var taskTitleBlock: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title)
                .font(.headline)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            if isSelectedForStart {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(accentColor)
            }
        }
    }

    private func taskMetricBlock(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(durationText)
                .font(.title3)
                .bold()
                .monospacedDigit()
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            Text(valueText)
                .font(.caption)
                .bold()
                .foregroundStyle(rowSecondaryStyle)
                .monospacedDigit()
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var rowSecondaryStyle: Color {
        colorScheme == .dark ? Color.white.opacity(0.66) : Color.black.opacity(0.60)
    }

    private var rowGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [Color.white.opacity(0.06), Color.black.opacity(0.20)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [Color.white, Color(red: 0.96, green: 0.97, blue: 0.99)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var rowStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.09)
    }

    private var rowShadow: Color {
        colorScheme == .dark ? Color.black.opacity(0.10) : Color.black.opacity(0.05)
    }
}

struct SessionRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let session: WorkSession
    let hourlyRate: Double?
    let availableTasks: [ProjectTask]
    let onAssignToTask: ((ProjectTask?) -> Void)?
    let onCreateTaskAndAssign: (() -> Void)?
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?

    private var hasActions: Bool {
        onAssignToTask != nil || onCreateTaskAndAssign != nil || onEdit != nil || onDelete != nil
    }

    private var usesStackedLayout: Bool {
        ProjectDetailLayoutMetrics.usesStackedRow(
            dynamicTypeSize: dynamicTypeSize,
            horizontalSizeClass: horizontalSizeClass
        )
    }

    private var rowSpacing: CGFloat {
        ProjectDetailLayoutMetrics.sessionRowSpacing(
            dynamicTypeSize: dynamicTypeSize,
            horizontalSizeClass: horizontalSizeClass
        )
    }

    private var rowPadding: CGFloat {
        ProjectDetailLayoutMetrics.sessionRowPadding(
            dynamicTypeSize: dynamicTypeSize,
            horizontalSizeClass: horizontalSizeClass
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            if usesStackedLayout {
                HStack(alignment: .top, spacing: 10) {
                    compactSessionInfoBlock

                    Spacer(minLength: 8)

                    actionMenu
                }

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(timeRangeText)
                        .font(.subheadline)
                        .foregroundStyle(rowSecondaryStyle)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)

                    statusBadge
                }

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    SessionDurationText(session: session)

                    Spacer(minLength: 0)

                    billedAmountView
                }
            } else {
                HStack(spacing: 18) {
                    sessionInfoBlock

                    Spacer()

                    statusBadge

                    actionMenu

                    VStack(alignment: .trailing, spacing: 6) {
                        SessionDurationText(session: session)
                        billedAmountView
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(rowPadding)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(rowGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(rowStroke, lineWidth: 1)
        )
        .shadow(color: rowShadow, radius: 6, x: 0, y: 3)
    }

    private var compactSessionInfoBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(TimeFormatting.shortDate(session.startedAt))
                .font(.headline)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            Text(session.displayTaskTitle)
                .font(.subheadline)
                .bold()
                .foregroundStyle(rowSecondaryStyle)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var sessionInfoBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(TimeFormatting.shortDate(session.startedAt))
                .font(.headline)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            Text(session.displayTaskTitle)
                .font(.subheadline)
                .bold()
                .foregroundStyle(rowSecondaryStyle)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            Text(timeRangeText)
                .font(.subheadline)
                .foregroundStyle(rowSecondaryStyle)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var timeRangeText: String {
        if let endedAt = session.endedAt {
            return "\(TimeFormatting.shortTime(session.startedAt)) - \(TimeFormatting.shortTime(endedAt))"
        }

        return "Seit \(TimeFormatting.shortTime(session.startedAt))"
    }

    @ViewBuilder
    private var actionMenu: some View {
        if hasActions {
            Menu {
                if let onAssignToTask, !availableTasks.isEmpty {
                    Menu("Aufgabe zuordnen") {
                        ForEach(availableTasks) { task in
                            Button(task.displayTitle) {
                                onAssignToTask(task)
                            }
                        }

                        if session.task != nil {
                            Divider()

                            Button("Zuordnung entfernen") {
                                onAssignToTask(nil)
                            }
                        }
                    }
                }

                if let onCreateTaskAndAssign {
                    Button(action: onCreateTaskAndAssign) {
                        Label("Neue Aufgabe erstellen + zuordnen", systemImage: "plus")
                    }
                }

                if (onAssignToTask != nil && !availableTasks.isEmpty) || onCreateTaskAndAssign != nil {
                    Divider()
                }

                if let onEdit {
                    Button(action: onEdit) {
                        Label("Bearbeiten", systemImage: "square.and.pencil")
                    }
                }

                if let onDelete {
                    Button(role: .destructive, action: onDelete) {
                        Label("Loeschen", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.headline)
                    .foregroundStyle(rowSecondaryStyle)
            }
#if os(macOS)
            .menuStyle(.borderlessButton)
#endif
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        Text(session.isActive ? "Aktiv" : "Beendet")
            .font(.caption)
            .bold()
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(session.isActive ? activeBadgeColor.opacity(0.16) : Color.gray.opacity(0.16))
            )
            .foregroundStyle(session.isActive ? activeBadgeColor : .secondary)
    }

    @ViewBuilder
    private var billedAmountView: some View {
        if let hourlyRate {
            if session.isActive {
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    amountLabel(
                        amount: max(session.duration(referenceDate: timeline.date) / 3600, 0) * max(hourlyRate, 0)
                    )
                }
            } else {
                amountLabel(
                    amount: max(session.recordedDuration / 3600, 0) * max(hourlyRate, 0)
                )
            }
        }
    }

    private func amountLabel(amount: Double) -> some View {
        Text(TimeFormatting.euroAmount(amount))
            .font(.caption)
            .bold()
            .foregroundStyle(rowSecondaryStyle)
            .monospacedDigit()
    }

    private var activeBadgeColor: Color {
        session.project?.projectAccentColor ?? .teal
    }

    private var rowSecondaryStyle: Color {
        colorScheme == .dark ? Color.white.opacity(0.66) : Color.black.opacity(0.60)
    }

    private var rowGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [Color.white.opacity(0.06), Color.black.opacity(0.20)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [Color.white, Color(red: 0.96, green: 0.97, blue: 0.99)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var rowStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.09)
    }

    private var rowShadow: Color {
        colorScheme == .dark ? Color.black.opacity(0.10) : Color.black.opacity(0.05)
    }
}

struct NewTaskAssignmentSheet: View {
    @Environment(\.dismiss) private var dismiss

    let project: ClientProject
    let session: WorkSession
    let onSave: (String) -> Bool

    @State private var taskTitle = ""
    @State private var validationMessage: String?

    private var trimmedTaskTitle: String {
        taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Neue Aufgabe fuer Zeiteintrag")
                .font(.title2)
                .bold()

            Text("\(project.displayClientName) - \(project.displayName)")
                .foregroundStyle(.secondary)

            Text("Eintrag: \(TimeFormatting.shortDate(session.startedAt)) \(TimeFormatting.shortTime(session.startedAt))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("Aufgabentitel", text: $taskTitle)
                .textFieldStyle(.roundedBorder)

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

                Button("Erstellen und zuordnen") {
                    validationMessage = nil

                    guard !trimmedTaskTitle.isEmpty else {
                        validationMessage = "Bitte gib einen Aufgabentitel ein."
                        return
                    }

                    if onSave(trimmedTaskTitle) {
                        dismiss()
                    } else {
                        validationMessage = "Die Aufgabe konnte nicht erstellt werden."
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(project.projectActionColor)
                .disabled(trimmedTaskTitle.isEmpty)
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

struct SessionDurationText: View {
    let session: WorkSession

    var body: some View {
        Group {
            if session.isActive {
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    durationLabel(interval: session.duration(referenceDate: timeline.date))
                }
            } else {
                durationLabel(interval: session.recordedDuration)
            }
        }
    }

    private func durationLabel(interval: TimeInterval) -> some View {
        Text(TimeFormatting.digitalDuration(interval))
            .font(.headline)
            .bold()
            .monospacedDigit()
    }
}
