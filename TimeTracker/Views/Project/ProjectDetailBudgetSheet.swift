import SwiftData
import SwiftUI

struct ProjectDetailBudgetSheet: View {
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

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            content(referenceDate: timeline.date)
        }
        .padding(sectionPadding)
#if os(macOS)
        .frame(minWidth: 620, minHeight: 440)
#else
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
#endif
    }

    @ViewBuilder
    private func content(referenceDate: Date) -> some View {
        let snapshot = viewModel.budgetSnapshot(referenceDate: referenceDate)

        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Projektbudget")
                    .font(.title2)
                    .bold()

                Spacer()

                Button(
                    viewModel.isEditingBudgetInSheet ? "Fertig" : "Bearbeiten",
                    systemImage: "gearshape.fill"
                ) {
                    viewModel.isEditingBudgetInSheet.toggle()
                }
                .buttonStyle(.bordered)

                Button("Schliessen", systemImage: "xmark") {
                    viewModel.isEditingBudgetInSheet = false
                    viewModel.isPresentingBudgetSheet = false
                }
                .buttonStyle(.bordered)
            }

            if let snapshot {
                HStack(alignment: .top, spacing: 20) {
                    BudgetProgressDonut(
                        snapshot: snapshot,
                        accentColor: viewModel.project.projectActionColor
                    )
                    .frame(width: 170, height: 170)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(viewModel.budgetValueText(snapshot.consumed, unit: snapshot.unit)) / \(viewModel.budgetValueText(snapshot.target, unit: snapshot.unit))")
                            .font(.title2)
                            .bold()
                            .monospacedDigit()

                        Text(snapshot.progressText)
                            .font(.headline)
                            .foregroundStyle(snapshot.isOverBudget ? ClientProject.stopActionColor : viewModel.project.projectActionColor)
                            .monospacedDigit()

                        Text(snapshot.statusText(unitFormatter: viewModel.budgetValueText(_:unit:)))
                            .font(.subheadline)
                            .bold()
                            .foregroundStyle(snapshot.isOverBudget ? ClientProject.stopActionColor : .secondary)
                            .monospacedDigit()

                        Text(viewModel.secondaryBudgetSummary(referenceDate: referenceDate, primaryUnit: snapshot.unit))
                            .font(.subheadline)
                            .bold()
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Spacer(minLength: 0)
                }
            } else if viewModel.project.budgetUnit == .amount && !viewModel.project.hasHourlyRate {
                Label(
                    "EUR-Budget kann erst mit hinterlegtem Stundensatz berechnet werden.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.subheadline)
                .bold()
                .foregroundStyle(.orange)
            } else {
                Text("Lege ein Stunden- oder Euro-Budget fest, damit der Projektverbrauch live verfolgt werden kann.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }

            if viewModel.isEditingBudgetInSheet {
                Divider()

                budgetEditor

                Text(viewModel.budgetHintText)
                    .font(.caption)
                    .foregroundStyle(viewModel.hasInvalidBudgetTarget ? .red : .secondary)
            } else {
                Text("Zum Aendern auf das Zahnrad klicken.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(sectionPadding)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.10 : 0.42),
                            Color.clear,
                            Color.black.opacity(colorScheme == .dark ? 0.12 : 0.04),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .allowsHitTesting(false)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.08),
                    lineWidth: 1
                )
                .allowsHitTesting(false)
        )
    }

    @ViewBuilder
    private var budgetEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            if usesStackedRows {
                Text("Budgettyp").font(.title3).bold()

                Picker("Budgettyp", selection: $viewModel.selectedBudgetUnit) {
                    Label("Stunden", systemImage: "clock").tag(ProjectBudgetUnit.hours)
                    Label("Euro", systemImage: "eurosign.circle").tag(ProjectBudgetUnit.amount)
                }
                .pickerStyle(.segmented)

                Text(viewModel.selectedBudgetUnit == .hours ? "Stundenbudget" : "Eurobudget")
                    .font(.title3).bold()

                TextField(
                    viewModel.selectedBudgetUnit == .hours ? "z. B. 20" : "z. B. 2500",
                    text: $viewModel.budgetTargetText
                )
                .textFieldStyle(.roundedBorder)

                Text(viewModel.selectedBudgetUnit == .hours ? "Stunden" : "EUR")
                    .foregroundStyle(.secondary)

                Button("Speichern") {
                    viewModel.saveBudget(modelContext: modelContext)
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.project.projectActionColor)
                .disabled(viewModel.hasInvalidBudgetTarget || viewModel.selectedBudgetUnit == .amount && !viewModel.project.hasHourlyRate)

                if viewModel.project.hasBudget {
                    Button("Entfernen", role: .destructive) {
                        viewModel.clearBudget(modelContext: modelContext)
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                HStack(alignment: .center, spacing: 14) {
                    Text("Budgettyp").font(.title3).bold()
                        .frame(width: 130, alignment: .leading)

                    Picker("Budgettyp", selection: $viewModel.selectedBudgetUnit) {
                        Label("Stunden", systemImage: "clock").tag(ProjectBudgetUnit.hours)
                        Label("Euro", systemImage: "eurosign.circle").tag(ProjectBudgetUnit.amount)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 290)
                }

                HStack(alignment: .center, spacing: 14) {
                    Text(viewModel.selectedBudgetUnit == .hours ? "Stundenbudget" : "Eurobudget")
                        .font(.title3).bold()
                        .frame(width: 130, alignment: .leading)

                    TextField(
                        viewModel.selectedBudgetUnit == .hours ? "z. B. 20" : "z. B. 2500",
                        text: $viewModel.budgetTargetText
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)

                    Text(viewModel.selectedBudgetUnit == .hours ? "Stunden" : "EUR")
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Spacer(minLength: 144)

                    Button("Speichern") {
                        viewModel.saveBudget(modelContext: modelContext)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(viewModel.project.projectActionColor)
                    .disabled(viewModel.hasInvalidBudgetTarget || viewModel.selectedBudgetUnit == .amount && !viewModel.project.hasHourlyRate)

                    if viewModel.project.hasBudget {
                        Button("Entfernen", role: .destructive) {
                            viewModel.clearBudget(modelContext: modelContext)
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
    }
}

#Preview {
    let project = ClientProject.sampleData[0]
    project.setBudget(unit: .hours, target: 20)
    let viewModel = ProjectDetailViewModel(project: project, activeSession: nil)
    viewModel.isPresentingBudgetSheet = true
    return ProjectDetailBudgetSheet(viewModel: viewModel)
        .modelContainer(ModelContainer.preview)
}
