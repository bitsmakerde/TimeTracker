import SwiftUI

struct ProjectDetailSummaryRow: View {
    let viewModel: ProjectDetailViewModel

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var gridMinimum: CGFloat {
        ProjectDetailLayoutMetrics.summaryGridMinimum(horizontalSizeClass: horizontalSizeClass)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            summaryGrid(referenceDate: timeline.date)
        }
    }

    @ViewBuilder
    private func summaryGrid(referenceDate: Date) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: gridMinimum), spacing: 14)],
            spacing: 14
        ) {
            SummaryCard(
                title: "Gesamtzeit",
                value: TimeFormatting.compactDuration(viewModel.totalDuration(referenceDate: referenceDate)),
                subtitle: "\(viewModel.project.sessionList.count) Sitzungen"
            )

            SummaryCard(
                title: "Gesamtwert",
                value: viewModel.totalValueText(referenceDate: referenceDate),
                subtitle: viewModel.project.hasHourlyRate ? "Aus Zeit und Stundensatz" : "Stundensatz fehlt"
            )

            SummaryCard(
                title: "Heute",
                value: TimeFormatting.compactDuration(viewModel.todayDuration(referenceDate: referenceDate)),
                subtitle: "Seit 00:00 Uhr"
            )

            SummaryCard(
                title: "Stundensatz",
                value: viewModel.hourlyRateSummary,
                subtitle: viewModel.project.hasHourlyRate ? "Pro Stunde" : "Noch nicht hinterlegt",
                accessorySystemImage: "gearshape.fill",
                accessoryAction: viewModel.toggleHourlyRateEditing
            )

            SummaryCard(
                title: "Budget",
                value: viewModel.budgetSummaryValue(referenceDate: referenceDate),
                subtitle: viewModel.budgetSummarySubtitle(referenceDate: referenceDate),
                accessorySystemImage: "info.circle",
                accessoryAction: viewModel.presentBudgetDetails
            )
        }
    }
}

#Preview {
    let project = ClientProject.sampleData[0]
    let viewModel = ProjectDetailViewModel(project: project, activeSession: nil)
    ProjectDetailSummaryRow(viewModel: viewModel)
        .padding()
}
