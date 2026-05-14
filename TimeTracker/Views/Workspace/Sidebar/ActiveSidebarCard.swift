import SwiftUI

struct ActiveSidebarCard: View {
    let project: ClientProject
    let session: WorkSession
    let task: ProjectTask?
    let onStop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Gerade aktiv")
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

            if let task {
                Text(task.displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(project.projectAccentColor)
            } else {
                Text("Ohne Aufgabe")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                Text(TimeFormatting.digitalDuration(session.duration(referenceDate: timeline.date)))
                    .font(.title2)
                    .bold()
                    .monospacedDigit()
            }

            Button("Tracking stoppen", action: onStop)
                .buttonStyle(.borderedProminent)
                .tint(ClientProject.stopActionColor)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [project.projectAccentColor.opacity(0.26), project.projectAccentColor.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}

#Preview("Active sidebar card") {
    let project = ClientProject.sampleData[0]
    let session = project.sessionList.first(where: \.isActive) ?? project.sessionList[0]

    return ActiveSidebarCard(
        project: project,
        session: session,
        task: session.task
    ) {}
    .padding()
    .frame(width: 320)
}
