import SwiftData
import SwiftUI

struct ProjectDetailBillingCard: View {
    @Bindable var viewModel: ProjectDetailViewModel

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
            HStack {
                Text(viewModel.project.hasHourlyRate ? "Stundensatz bearbeiten" : "Stundensatz hinterlegen")
                    .font(.title2)
                    .bold()
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                if viewModel.project.hasHourlyRate {
                    Button("Schliessen") {
                        viewModel.isEditingHourlyRate = false
                        viewModel.syncHourlyRateText()
                    }
                    .buttonStyle(.bordered)
                }
            }

            if usesStackedRows {
                stackedRateEditor
            } else {
                inlineRateEditor
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

    private var stackedRateEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stundensatz")
                .font(.subheadline)
                .bold()
                .foregroundStyle(.secondary)

            TextField("z. B. 95,00", text: $viewModel.hourlyRateText)
                .textFieldStyle(.roundedBorder)

            Text("EUR pro Stunde")
                .foregroundStyle(.secondary)

            Text(viewModel.hourlyRateHint)
                .font(.caption)
                .foregroundStyle(viewModel.hasInvalidHourlyRate ? .red : .secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            Button("Stundensatz speichern") {
                viewModel.saveHourlyRate(modelContext: modelContext)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.project.projectActionColor)
            .disabled(viewModel.hasInvalidHourlyRate)
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text("Aktueller Satz")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(.secondary)

                Text(viewModel.hourlyRateSummary)
                    .font(.title2)
                    .bold()
                    .monospacedDigit()
            }
        }
    }

    private var inlineRateEditor: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Stundensatz")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    TextField("z. B. 95,00", text: $viewModel.hourlyRateText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 160)

                    Text("EUR pro Stunde")
                        .foregroundStyle(.secondary)
                }

                Text(viewModel.hourlyRateHint)
                    .font(.caption)
                    .foregroundStyle(viewModel.hasInvalidHourlyRate ? .red : .secondary)
            }

            Button("Stundensatz speichern") {
                viewModel.saveHourlyRate(modelContext: modelContext)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.project.projectActionColor)
            .disabled(viewModel.hasInvalidHourlyRate)

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text("Aktueller Satz")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(.secondary)

                Text(viewModel.hourlyRateSummary)
                    .font(.title2)
                    .bold()
                    .monospacedDigit()
            }
        }
    }
}

#Preview {
    let project = ClientProject.sampleData[0]
    let viewModel = ProjectDetailViewModel(project: project, activeSession: nil)
    viewModel.isEditingHourlyRate = true
    return ProjectDetailBillingCard(viewModel: viewModel)
        .padding()
        .modelContainer(ModelContainer.preview)
}
