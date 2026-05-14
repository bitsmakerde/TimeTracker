import SwiftData
import SwiftUI

struct ProjectDetailSessionsCard: View {
    let viewModel: ProjectDetailViewModel
    let onAddManualEntry: () -> Void
    let onEditSession: (WorkSession) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var sectionPadding: CGFloat { ProjectDetailLayoutMetrics.sectionPadding(horizontalSizeClass: horizontalSizeClass) }
    private var cornerRadius: CGFloat { ProjectDetailLayoutMetrics.sectionCornerRadius(horizontalSizeClass: horizontalSizeClass) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text("Letzte Eintraege").font(.title2).bold()
                    Spacer()
                    Button(action: onAddManualEntry) {
                        Label("Nachtragen", systemImage: "plus.circle")
                    }
                    Text("\(viewModel.project.sessionList.count) gesamt")
                        .font(.subheadline).foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Letzte Eintraege").font(.title2).bold()
                        Spacer()
                        Text("\(viewModel.project.sessionList.count) gesamt")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Button(action: onAddManualEntry) {
                        Label("Nachtragen", systemImage: "plus.circle")
                    }
                }
            }

            if viewModel.project.sortedSessions.isEmpty {
                Text("Noch keine Zeit erfasst. Starte oben den ersten Timer fuer dieses Projekt.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 18)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.project.sortedSessions) { session in
                        SessionRow(
                            session: session,
                            hourlyRate: viewModel.project.hourlyRate,
                            availableTasks: viewModel.project.sortedTasks,
                            onAssignToTask: { task in
                                viewModel.assignSession(session, to: task, modelContext: modelContext)
                            },
                            onCreateTaskAndAssign: {
                                viewModel.sessionPendingTaskCreation = session
                            },
                            onEdit: session.isActive ? nil : {
                                onEditSession(session)
                            },
                            onDelete: session.isActive ? nil : {
                                viewModel.sessionPendingDeletion = session
                            }
                        )
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
}

#Preview {
    let projects = ClientProject.sampleData
    let project = projects[0]
    let activeSessions = WorkSession.sampleActiveData(for: projects)
    let viewModel = ProjectDetailViewModel(project: project, activeSession: activeSessions.first)
    return ProjectDetailSessionsCard(
        viewModel: viewModel,
        onAddManualEntry: {},
        onEditSession: { _ in }
    )
    .padding()
    .modelContainer(ModelContainer.preview)
}
