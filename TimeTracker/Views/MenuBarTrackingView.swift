import SwiftData
import SwiftUI

struct MenuBarTrackingView: View {
    @Environment(\.modelContext) private var modelContext
    let trackingStatus: TrackingStatusStore
    let dependencies: AppDependencies

    @Query(
        sort: [
            SortDescriptor(\ClientProject.clientName),
            SortDescriptor(\ClientProject.name),
        ]
    )
    private var projects: [ClientProject]

    @Query(
        filter: #Predicate<WorkSession> { session in
            session.endedAt == nil
        },
        sort: [SortDescriptor(\WorkSession.startedAt, order: .forward)]
    )
    private var activeSessions: [WorkSession]

    @State private var errorMessage: String?

    private var activeSession: WorkSession? {
        activeSessions.first
    }

    private var activeProject: ClientProject? {
        activeSession?.project
    }

    private var startableProjects: [ClientProject] {
        projects.filter { project in
            project.id != activeProject?.id && !project.isArchived
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MenuBarSyncStatusRow(trackingStatus: trackingStatus)

            if let crossDeviceTrackingSnapshot = trackingStatus.crossDeviceTrackingSnapshot {
                MenuBarCrossDeviceStatusRow(snapshot: crossDeviceTrackingSnapshot)
            }

            if let activeSession, let activeProject {
                activeTrackingCard(project: activeProject, session: activeSession)
            } else {
                idleCard
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Projekt starten")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                if startableProjects.isEmpty {
                    Text("Es gibt gerade keine startbaren Projekte.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(startableProjects.prefix(6)) { project in
                        Button {
                            startTracking(project)
                        } label: {
                            HStack {
                                Circle()
                                    .fill(project.projectAccentColor)
                                    .frame(width: 10, height: 10)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(project.displayName)
                                        .foregroundStyle(.primary)

                                    Text(project.displayClientName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    if !project.taskList.isEmpty {
                                        Text("Startet ohne Aufgabe")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Image(systemName: "play.fill")
                                    .foregroundStyle(project.projectAccentColor)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 320)
        .alert("Aktion fehlgeschlagen", isPresented: alertIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func activeTrackingCard(project: ClientProject, session: WorkSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Aktive Zeiterfassung")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Circle()
                    .fill(project.projectAccentColor)
                    .frame(width: 10, height: 10)

                Text(project.displayName)
                    .font(.headline)
            }

            Text(project.displayClientName)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(session.displayTaskTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(project.projectAccentColor)

            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                Text(TimeFormatting.digitalDuration(session.duration(referenceDate: timeline.date)))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }

            Button(role: .destructive) {
                stopTracking()
            } label: {
                Label("Tracking stoppen", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(ClientProject.stopActionColor)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [project.projectAccentColor.opacity(0.24), project.projectAccentColor.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private var idleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Keine aktive Zeiterfassung")
                .font(.headline)

            Text("Starte ein Projekt direkt aus der Menüleiste.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private var alertIsPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    errorMessage = nil
                }
            }
        )
    }

    private func startTracking(_ project: ClientProject) {
        do {
            try dependencies.workspaceTrackingUseCases.startTracking(
                project: project,
                task: nil,
                in: modelContext,
                at: .now
            )
            trackingStatus.refresh()
        } catch let trackingError as TrackingManagerError {
            errorMessage = trackingError.errorDescription
        } catch {
            errorMessage = "Die Zeiterfassung konnte nicht gestartet werden."
        }
    }

    private func stopTracking() {
        do {
            try dependencies.workspaceTrackingUseCases.stopActiveTracking(
                in: modelContext,
                at: .now
            )
            trackingStatus.refresh()
        } catch {
            errorMessage = "Die laufende Zeiterfassung konnte nicht beendet werden."
        }
    }
}

private struct MenuBarCrossDeviceStatusRow: View {
    let snapshot: CrossDeviceTrackingSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .bold()

            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private var title: String {
        switch snapshot.lifecycle {
        case .started:
            return "Anderes Geraet: Start"
        case .stopped:
            return "Anderes Geraet: Stopp"
        }
    }

    private var detail: String {
        let startTime = snapshot.startedAt.formatted(date: .omitted, time: .shortened)
        return "\(snapshot.projectName) - \(snapshot.taskTitle) - Start \(startTime)"
    }
}

private struct MenuBarSyncStatusRow: View {
    let trackingStatus: TrackingStatusStore

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbolName)
                .foregroundStyle(tintColor)

            Text(title)
                .font(.caption)
                .bold()

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private var title: String {
        switch trackingStatus.syncStatus {
        case .localOnly:
            return "Sync lokal"
        case .waitingForCloud:
            return "Sync bereit"
        case let .syncing(operation, _):
            switch operation {
            case .setup:
                return "Sync Setup"
            case .importData:
                return "Sync Import"
            case .export:
                return "Sync Export"
            }
        case .upToDate:
            return "Sync aktuell"
        case .failed:
            return "Sync Fehler"
        }
    }

    private var symbolName: String {
        switch trackingStatus.syncStatus {
        case .localOnly:
            return "icloud.slash"
        case .waitingForCloud:
            return "icloud"
        case .syncing:
            return "arrow.triangle.2.circlepath.icloud"
        case .upToDate:
            return "checkmark.icloud"
        case .failed:
            return "exclamationmark.icloud"
        }
    }

    private var tintColor: Color {
        switch trackingStatus.syncStatus {
        case .localOnly, .waitingForCloud:
            return .secondary
        case .syncing:
            return .teal
        case .upToDate:
            return .green
        case .failed:
            return .orange
        }
    }
}

struct MenuBarStatusLabel: View {
    let trackingStatus: TrackingStatusStore

    var body: some View {
        if trackingStatus.isTracking {
            (Text(Image(systemName: "timer")) + Text(" \(trackingStatus.menuBarDurationText)"))
                .monospacedDigit()
        } else if let crossDeviceDuration = trackingStatus.menuBarCrossDeviceDurationText {
            (Text(Image(systemName: "dot.radiowaves.left.and.right")) + Text(" \(crossDeviceDuration)"))
                .monospacedDigit()
        } else {
            Image(systemName: "timer")
        }
    }
}

#Preview("Menu bar tracking") {
    MenuBarTrackingPreviewHost()
}

#Preview("Menu bar status label") {
    MenuBarStatusLabelPreviewHost()
}

@MainActor
private struct MenuBarTrackingPreviewHost: View {
    private let preview = PreviewWorkspaceSnapshot()

    var body: some View {
        MenuBarTrackingView(
            trackingStatus: preview.trackingStatus,
            dependencies: .live(configuration: TimeTrackerTargetConfiguration.macOS)
        )
        .modelContainer(preview.modelContainer)
        .padding()
    }
}

@MainActor
private struct MenuBarStatusLabelPreviewHost: View {
    private let preview = PreviewWorkspaceSnapshot()

    var body: some View {
        MenuBarStatusLabel(trackingStatus: preview.trackingStatus)
            .modelContainer(preview.modelContainer)
            .padding()
    }
}
