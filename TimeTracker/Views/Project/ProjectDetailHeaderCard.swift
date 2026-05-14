import SwiftData
import SwiftUI

struct ProjectDetailHeaderCard: View {
    let viewModel: ProjectDetailViewModel
    let onStart: () -> Void
    let onStartTask: (ProjectTask) -> Void
    let onStop: () -> Void
    let onAddManualEntry: () -> Void
    let onArchiveProject: () -> Void
    let onRestoreProject: () -> Void
    let onDeleteProject: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompactWidth: Bool { horizontalSizeClass == .compact }
    private var cornerRadius: CGFloat { ProjectDetailLayoutMetrics.headerCornerRadius(horizontalSizeClass: horizontalSizeClass) }
    private var sectionPadding: CGFloat { ProjectDetailLayoutMetrics.sectionPadding(horizontalSizeClass: horizontalSizeClass) }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompactWidth ? 16 : 20) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 20) {
                    primaryInfo
                    Spacer()
                    actionPanel(alignment: .trailing)
                }

                VStack(alignment: .leading, spacing: 16) {
                    primaryInfo
                    actionPanel(alignment: .leading)
                }
            }

            if let archivedAt = viewModel.project.archivedAt {
                archiveStatusBadge(archivedAt: archivedAt)
            }

            if viewModel.isActiveProject, let activeSession = viewModel.activeSession {
                activeSessionBanner(activeSession: activeSession)
            }
        }
        .padding(sectionPadding)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(cardGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(strokeStyle, lineWidth: 1)
        )
        .shadow(color: shadowStyle, radius: 18, x: 0, y: 12)
    }

    private var primaryInfo: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Circle()
                    .fill(viewModel.project.projectAccentColor)
                    .frame(width: 14, height: 14)

                Text(viewModel.project.displayName)
                    .font(.largeTitle)
                    .bold()
                    .foregroundStyle(primaryTextStyle)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(viewModel.project.displayClientName)
                .font(.title3)
                .foregroundStyle(secondaryTextStyle)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            if !viewModel.project.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(viewModel.project.notes)
                    .font(.body)
                    .foregroundStyle(secondaryTextStyle)
                    .padding(.top, 2)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func actionPanel(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 10) {
            actionButton

            if !viewModel.project.isArchived {
                manualEntryButton
            }

            projectActionsButton
            colorControls

            if !viewModel.project.isArchived, let selectedTask = viewModel.selectedTaskForStart {
                Label("Aktiv: \(selectedTask.displayTitle)", systemImage: "scope")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(secondaryTextStyle)
                    .frame(maxWidth: isCompactWidth ? .infinity : 260, alignment: isCompactWidth ? .leading : .trailing)
                    .multilineTextAlignment(isCompactWidth ? .leading : .trailing)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !viewModel.project.isArchived,
               let activeSession = viewModel.activeSession,
               let activeProject = activeSession.project,
               activeProject.id != viewModel.project.id {
                Text("Beim Start wird \(activeProject.displayName) automatisch gestoppt.")
                    .font(.caption)
                    .foregroundStyle(secondaryTextStyle)
                    .frame(maxWidth: isCompactWidth ? .infinity : 260, alignment: isCompactWidth ? .leading : .trailing)
                    .multilineTextAlignment(isCompactWidth ? .leading : .trailing)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: isCompactWidth ? .infinity : nil, alignment: isCompactWidth ? .leading : .trailing)
    }

    private var actionButton: some View {
        Button(action: {
            if viewModel.project.isArchived {
                onRestoreProject()
            } else if viewModel.isActiveProject {
                onStop()
            } else if let selectedTask = viewModel.selectedTaskForStart {
                onStartTask(selectedTask)
            } else {
                onStart()
            }
        }) {
            Label(viewModel.actionButtonTitle, systemImage: viewModel.actionButtonSystemImage)
                .frame(minWidth: isCompactWidth ? nil : 220)
                .frame(maxWidth: isCompactWidth ? .infinity : nil)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(viewModel.actionButtonTint)
    }

    private var manualEntryButton: some View {
        Button(action: onAddManualEntry) {
            Label("Eintrag nachtragen", systemImage: "calendar.badge.plus")
                .frame(minWidth: isCompactWidth ? nil : 220)
                .frame(maxWidth: isCompactWidth ? .infinity : nil)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    private var projectActionsButton: some View {
        Menu {
            if viewModel.project.isArchived {
                Button(action: onRestoreProject) {
                    Label("Projekt reaktivieren", systemImage: "arrow.uturn.backward.circle")
                }
            } else {
                Button {
                    viewModel.isConfirmingProjectArchive = true
                } label: {
                    Label("Projekt abschliessen", systemImage: "archivebox.fill")
                }
            }

            Divider()

            Button(action: viewModel.presentProjectExportSheet) {
                Label("Projekt exportieren", systemImage: "square.and.arrow.up")
            }

            Divider()

            Button(role: .destructive) {
                viewModel.isConfirmingProjectDeletion = true
            } label: {
                Label("Projekt loeschen", systemImage: "trash")
            }
        } label: {
            Label("Projekt", systemImage: "ellipsis.circle")
                .frame(minWidth: isCompactWidth ? nil : 220)
                .frame(maxWidth: isCompactWidth ? .infinity : nil)
        }
#if os(macOS)
        .menuStyle(.borderlessButton)
#endif
        .controlSize(.large)
    }

    private var colorControls: some View {
        HStack(spacing: 10) {
            Text("Farbe")
                .font(.caption)
                .bold()
                .foregroundStyle(secondaryTextStyle)

            ColorPicker(
                "Projektfarbe",
                selection: Binding(
                    get: { viewModel.project.projectAccentColor },
                    set: { viewModel.saveProjectAccentColor($0, modelContext: modelContext) }
                ),
                supportsOpacity: false
            )
            .labelsHidden()
            .controlSize(.small)

            if viewModel.project.hasCustomAccentColor {
                Button("Auto") {
                    viewModel.resetProjectAccentColor(modelContext: modelContext)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .frame(maxWidth: isCompactWidth ? .infinity : 260, alignment: isCompactWidth ? .leading : .trailing)
    }

    private func archiveStatusBadge(archivedAt: Date) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "archivebox.fill")
                .foregroundStyle(secondaryTextStyle)

            Text("Archiviert am \(TimeFormatting.shortDate(archivedAt))")
                .font(.headline)
                .foregroundStyle(secondaryTextStyle)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(innerSurfaceStyle)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(strokeStyle, lineWidth: 1)
        )
    }

    private func activeSessionBanner(activeSession: WorkSession) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "timer")
                .foregroundStyle(viewModel.project.projectAccentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(activeSession.displayTaskTitle)
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(secondaryTextStyle)

                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    Text("Laeuft seit \(TimeFormatting.shortTime(activeSession.startedAt)) - \(TimeFormatting.digitalDuration(activeSession.duration(referenceDate: timeline.date)))")
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(primaryTextStyle)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(innerSurfaceStyle)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(strokeStyle, lineWidth: 1)
        )
    }

    // MARK: - Styling

    private var primaryTextStyle: Color {
        colorScheme == .dark ? Color.white.opacity(0.96) : Color.black.opacity(0.9)
    }
    private var secondaryTextStyle: Color {
        colorScheme == .dark ? Color.white.opacity(0.78) : Color.black.opacity(0.62)
    }
    private var innerSurfaceStyle: Color {
        colorScheme == .dark ? Color.black.opacity(0.28) : Color.white.opacity(0.72)
    }
    private var strokeStyle: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.06)
    }
    private var shadowStyle: Color {
        colorScheme == .dark ? Color.black.opacity(0.32) : Color.black.opacity(0.05)
    }
    private var cardGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color.black.opacity(0.30),
                    viewModel.project.projectAccentColor.opacity(0.34),
                    Color.black.opacity(0.18),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [Color.white.opacity(0.94), viewModel.project.projectAccentColor.opacity(0.20)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#Preview {
    let project = ClientProject.sampleData[0]
    let viewModel = ProjectDetailViewModel(project: project, activeSession: nil)
    ProjectDetailHeaderCard(
        viewModel: viewModel,
        onStart: {},
        onStartTask: { _ in },
        onStop: {},
        onAddManualEntry: {},
        onArchiveProject: {},
        onRestoreProject: {},
        onDeleteProject: {}
    )
    .padding()
    .modelContainer(ModelContainer.preview)
}
