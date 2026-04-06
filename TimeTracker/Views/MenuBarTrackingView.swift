import SwiftData
import SwiftUI

struct MenuBarTrackingView: View {
    @Environment(\.modelContext) private var modelContext
    let trackingStatus: TrackingStatusStore

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
        sort: [SortDescriptor(\WorkSession.startedAt, order: .reverse)]
    )
    private var activeSessions: [WorkSession]

    @State private var errorMessage: String?

    private let trackingManager = TrackingManager()

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

                                    if !project.tasks.isEmpty {
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
            try trackingManager.startTracking(project: project, in: modelContext)
            trackingStatus.refresh()
        } catch let trackingError as TrackingManagerError {
            errorMessage = trackingError.errorDescription
        } catch {
            errorMessage = "Die Zeiterfassung konnte nicht gestartet werden."
        }
    }

    private func stopTracking() {
        do {
            try trackingManager.stopActiveTracking(in: modelContext)
            trackingStatus.refresh()
        } catch {
            errorMessage = "Die laufende Zeiterfassung konnte nicht beendet werden."
        }
    }
}

struct MenuBarStatusLabel: View {
    let trackingStatus: TrackingStatusStore

    var body: some View {
        if trackingStatus.isTracking {
            (Text(Image(systemName: "timer")) + Text(" \(trackingStatus.menuBarDurationText)"))
                .monospacedDigit()
        } else {
            Image(systemName: "timer")
        }
    }
}
