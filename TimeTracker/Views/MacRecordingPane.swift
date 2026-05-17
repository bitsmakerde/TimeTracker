import SwiftData
import SwiftUI

struct MacAufnehmenPane: View {
    let project: ClientProject
    let activeSession: WorkSession?
    let onStartTask: (ProjectTask) -> Void
    let onStartProject: () -> Void
    let onStop: () -> Void
    let onAddManualEntry: () -> Void
    let onEditEntry: (WorkSession) -> Void
    let onEditTask: (ProjectTask) -> Void
    let onAddTask: (String) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var newTaskText: String = ""
    @State private var showRatePopover = false
    @State private var showBudgetPopover = false
    @State private var rateInputText = ""
    @State private var budgetInputText = ""
    @State private var budgetInputUnit: ProjectBudgetUnit = .hours

    private var isRunningOnThisProject: Bool {
        activeSession?.project?.id == project.id
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                breadcrumb
                kpiGrid
                VStack(spacing: 14) {
                    tasksCard.frame(maxWidth: .infinity)
                    entriesCard.frame(maxWidth: .infinity)
                }
            }
            .padding(TTSpacing.lg)
        }
    }

    private var breadcrumb: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(project.projectAccentColor)
                        .frame(width: 16, height: 16)
                    Text(String(project.displayClientName.prefix(1)).uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text("KUNDE · \(project.displayClientName.uppercased())")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.2)
                    .foregroundStyle(TTColors.text)
            }
            .padding(.leading, 5)
            .padding(.trailing, 9)
            .padding(.vertical, 3)
            .background(project.projectAccentColor.opacity(0.10), in: Capsule())
            .overlay(Capsule().strokeBorder(project.projectAccentColor.opacity(0.25), lineWidth: 0.5))

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(TTColors.text3)

            Text(project.displayName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(TTColors.text)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(TTColors.surface2, in: .rect(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(TTColors.text4, lineWidth: 0.5)
        }
    }

    private var kpiGrid: some View {
        let total = project.sessionList.reduce(0.0) { $0 + $1.recordedDuration }
        let value = project.billedAmount(for: total) ?? 0
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: .now)
        let today = project.sessionList.reduce(0.0) { result, session in
            let start = max(session.startedAt, startOfDay)
            let end = session.endedAt ?? .now
            return result + max(end.timeIntervalSince(start), 0)
        }

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
            StatTile("Gesamtzeit", value: TimeFormatting.compactDuration(total), sub: "\(project.sessionList.count) Einträge")
            StatTile("Gesamtwert", value: TimeFormatting.euroAmount(value), sub: "Zeit × Satz")
            StatTile("Heute", value: TimeFormatting.compactDuration(today), sub: "Seit 00:00")
            StatTile("Stundensatz", value: project.hourlyRate.map { TimeFormatting.euroAmount($0) } ?? "—", sub: "Pro Stunde", action: {
                rateInputText = project.hourlyRate.map { $0.formatted(.number.precision(.fractionLength(0))) } ?? ""
                showRatePopover = true
            })
            .popover(isPresented: $showRatePopover) { rateEditorPopover }

            StatTile("Budget", value: macBudgetDisplayValue, sub: macBudgetDisplaySub, action: {
                budgetInputUnit = project.budgetUnit ?? .hours
                budgetInputText = project.effectiveBudgetTarget.map { $0.formatted(.number.precision(.fractionLength(0))) } ?? ""
                showBudgetPopover = true
            })
            .popover(isPresented: $showBudgetPopover) { budgetEditorPopover }
        }
    }

    private var tasksCard: some View {
        MacWorkSectionCard {
            HStack(alignment: .firstTextBaseline) {
                Text("Aufgaben · \(project.displayName)")
                    .font(.title2)
                    .foregroundStyle(TTColors.text)
                Spacer(minLength: TTSpacing.md)
                Text("\(project.sortedTasks.count) gesamt")
                    .font(.title3)
                    .foregroundStyle(TTColors.text3)
            }

            HStack(spacing: TTSpacing.md) {
                TextField("Neue Aufgabe …", text: $newTaskText)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .padding(.horizontal, TTSpacing.lg)
                    .frame(height: 46)
                    .background(TTColors.fill4, in: .rect(cornerRadius: TTRadius.md, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: TTRadius.md, style: .continuous)
                            .strokeBorder(TTColors.text4, lineWidth: 0.5)
                    }

                Button("Hinzufügen") {
                    let title = newTaskText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard title.isEmpty == false else { return }
                    onAddTask(title)
                    newTaskText = ""
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(TTColors.accent)
            }

            if project.sortedTasks.isEmpty {
                Text("Noch keine Aufgaben")
                    .font(.body)
                    .foregroundStyle(TTColors.text2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, TTSpacing.md)
            } else {
                VStack(spacing: TTSpacing.md) {
                    ForEach(project.sortedTasks, id: \.id) { task in
                        let isRunning = isRunningOnThisProject && activeSession?.task?.id == task.id
                        let total = task.sessionList.reduce(0.0) { $0 + $1.recordedDuration }
                        MacTaskListRow(
                            title: task.displayTitle,
                            subtitle: taskSubtitle(for: task),
                            duration: TimeFormatting.compactDuration(total),
                            value: project.billedAmount(for: total).map(TimeFormatting.euroAmount) ?? "0,00 €",
                            isRunning: isRunning,
                            onPlayPause: {
                                if isRunning { onStop() } else { onStartTask(task) }
                            },
                            onAddEntry: onAddManualEntry,
                            onEdit: { onEditTask(task) }
                        )
                    }
                }
            }
        }
    }

    private var entriesCard: some View {
        MacWorkSectionCard {
            HStack(alignment: .firstTextBaseline) {
                Text("Letzte Einträge")
                    .font(.title2)
                    .foregroundStyle(TTColors.text)
                Spacer(minLength: TTSpacing.md)
                Button("Nachtragen", systemImage: "plus", action: onAddManualEntry)
                    .buttonStyle(.plain)
                    .font(.title3)
                    .foregroundStyle(TTColors.accent)
            }

            let recent = Array(project.sortedSessions.prefix(8))
            if recent.isEmpty {
                Text("Noch keine Einträge")
                    .font(.body)
                    .foregroundStyle(TTColors.text2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, TTSpacing.md)
            } else {
                VStack(spacing: 0) {
                    ForEach(recent, id: \.id) { session in
                        MacEntryListRow(
                            timeRange: timeRange(session),
                            taskName: session.displayTaskTitle,
                            context: "\(project.displayClientName) › \(project.displayName)",
                            duration: TimeFormatting.compactDuration(session.recordedDuration),
                            onTap: { onEditEntry(session) }
                        )
                        if session.id != recent.last?.id {
                            Divider().background(TTColors.separator)
                        }
                    }
                }
            }
        }
    }

    private func taskSubtitle(for task: ProjectTask) -> String {
        let entryCount = task.sessionList.count
        let entryText = "\(entryCount) Eintrag\(entryCount == 1 ? "" : "e")"
        guard let hourlyRate = project.hourlyRate else { return entryText }
        return "\(entryText) · \(TimeFormatting.euroAmount(hourlyRate))/h"
    }

    private func timeRange(_ session: WorkSession) -> String {
        let start = TimeFormatting.shortTime(session.startedAt)
        let end = session.endedAt.map { TimeFormatting.shortTime($0) } ?? "…"
        return "\(start)–\(end)"
    }

    @ViewBuilder
    private var rateEditorPopover: some View {
        VStack(alignment: .leading, spacing: TTSpacing.md) {
            Text("Stundensatz").font(.headline)
            HStack(spacing: TTSpacing.sm) {
                TextField("z. B. 85", text: $rateInputText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                Text("€/h").foregroundStyle(.secondary)
            }
            HStack(spacing: TTSpacing.sm) {
                Button("Speichern") {
                    let normalized = rateInputText.replacing(",", with: ".")
                    if let value = Double(normalized), value > 0 {
                        project.hourlyRate = value
                    } else if rateInputText.trimmingCharacters(in: .whitespaces).isEmpty {
                        project.hourlyRate = nil
                    }
                    try? modelContext.save()
                    showRatePopover = false
                }
                .buttonStyle(.borderedProminent)
                .tint(project.projectAccentColor)
                Button("Abbrechen") { showRatePopover = false }
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(width: 220)
    }

    @ViewBuilder
    private var budgetEditorPopover: some View {
        VStack(alignment: .leading, spacing: TTSpacing.md) {
            Text("Budget").font(.headline)
            Picker("", selection: $budgetInputUnit) {
                Label("Stunden", systemImage: "clock").tag(ProjectBudgetUnit.hours)
                Label("Euro", systemImage: "eurosign.circle").tag(ProjectBudgetUnit.amount)
            }
            .pickerStyle(.segmented)
            HStack(spacing: TTSpacing.sm) {
                TextField(budgetInputUnit == .hours ? "z. B. 20" : "z. B. 2500", text: $budgetInputText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                Text(budgetInputUnit == .hours ? "Std." : "EUR")
                    .foregroundStyle(.secondary)
            }
            if budgetInputUnit == .amount && !project.hasHourlyRate {
                Label("Stundensatz erforderlich.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            HStack(spacing: TTSpacing.sm) {
                Button("Speichern") {
                    saveBudgetMac()
                    showBudgetPopover = false
                }
                .buttonStyle(.borderedProminent)
                .tint(project.projectAccentColor)
                .disabled(budgetInputUnit == .amount && !project.hasHourlyRate)
                if project.hasBudget {
                    Button("Entfernen", role: .destructive) {
                        project.clearBudget()
                        try? modelContext.save()
                        showBudgetPopover = false
                    }
                    .buttonStyle(.bordered)
                }
                Button("Abbrechen") { showBudgetPopover = false }
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(width: 260)
    }

    private func saveBudgetMac() {
        let normalized = budgetInputText.replacing(",", with: ".")
        if let value = Double(normalized), value > 0 {
            project.setBudget(unit: budgetInputUnit, target: value)
        } else {
            project.clearBudget()
        }
        try? modelContext.save()
    }

    private var macBudgetDisplayValue: String {
        guard let unit = project.budgetUnit, let target = project.effectiveBudgetTarget else {
            return "Offen"
        }
        switch unit {
        case .hours: return TimeFormatting.compactDuration(target * 3600)
        case .amount: return TimeFormatting.euroAmount(target)
        }
    }

    private var macBudgetDisplaySub: String {
        switch project.budgetUnit {
        case .hours: return "Std.-Budget"
        case .amount: return "€-Budget"
        case nil: return "Keine Grenze"
        }
    }
}

private struct MacWorkSectionCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TTSpacing.xl) {
            content
        }
        .padding(.horizontal, TTSpacing.xl)
        .padding(.vertical, TTSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TTColors.surface, in: .rect(cornerRadius: TTRadius.xl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: TTRadius.xl, style: .continuous)
                .strokeBorder(TTColors.text4, lineWidth: 0.75)
        }
    }
}

private struct MacTaskListRow: View {
    let title: String
    let subtitle: String
    let duration: String
    let value: String
    let isRunning: Bool
    let onPlayPause: () -> Void
    let onAddEntry: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: TTSpacing.lg) {
            Button(isRunning ? "Pause" : "Start", systemImage: isRunning ? "pause.fill" : "play.fill", action: onPlayPause)
                .labelStyle(.iconOnly)
                .font(.title3)
                .foregroundStyle(TTColors.text)
                .frame(width: 48, height: 48)
                .background(TTColors.fill4, in: .rect(cornerRadius: TTRadius.md, style: .continuous))
                .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: TTSpacing.xs) {
                Text(title)
                    .font(.title3)
                    .foregroundStyle(TTColors.text)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(TTColors.text3)
                    .lineLimit(1)
            }

            Spacer(minLength: TTSpacing.lg)

            HStack(spacing: TTSpacing.lg) {
                Button("Eintrag nachtragen", systemImage: "plus.circle", action: onAddEntry)
                    .labelStyle(.iconOnly)
                Button("Aufgabe bearbeiten", systemImage: "square.and.pencil", action: onEdit)
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.plain)
            .font(.title3)
            .foregroundStyle(TTColors.text)

            VStack(alignment: .trailing, spacing: TTSpacing.xs) {
                Text(duration)
                    .font(.title2)
                    .monospacedDigit()
                    .foregroundStyle(TTColors.text)
                Text(value)
                    .font(.body)
                    .monospacedDigit()
                    .foregroundStyle(TTColors.text3)
            }
            .frame(minWidth: 76, alignment: .trailing)
        }
        .padding(.horizontal, TTSpacing.xl)
        .padding(.vertical, TTSpacing.md)
        .frame(minHeight: 72)
        .background(TTColors.fill4, in: .rect(cornerRadius: TTRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: TTRadius.lg, style: .continuous)
                .strokeBorder(TTColors.text4, lineWidth: 0.75)
        }
    }
}

private struct MacEntryListRow: View {
    let timeRange: String
    let taskName: String
    let context: String
    let duration: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: TTSpacing.xl) {
                Text(timeRange)
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(TTColors.text3)
                    .frame(width: 200, alignment: .leading)

                VStack(alignment: .leading, spacing: TTSpacing.xs) {
                    Text(taskName)
                        .font(.title3)
                        .foregroundStyle(TTColors.text)
                        .lineLimit(1)
                    Text(context)
                        .font(.body)
                        .foregroundStyle(TTColors.text3)
                        .lineLimit(1)
                }

                Spacer(minLength: TTSpacing.lg)

                Text(duration)
                    .font(.title2)
                    .monospacedDigit()
                    .foregroundStyle(TTColors.text)
            }
            .padding(.vertical, TTSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview("Mac aufnehmen pane") {
    MacAufnehmenPanePreviewHost()
        .frame(width: 1080, height: 760)
}

@MainActor
private struct MacAufnehmenPanePreviewHost: View {
    private let preview = PreviewWorkspaceSnapshot()

    var body: some View {
        let project = preview.projects[0]

        MacAufnehmenPane(
            project: project,
            activeSession: preview.activeSessions.first,
            onStartTask: { _ in },
            onStartProject: {},
            onStop: {},
            onAddManualEntry: {},
            onEditEntry: { _ in },
            onEditTask: { _ in },
            onAddTask: { _ in }
        )
    }
}
