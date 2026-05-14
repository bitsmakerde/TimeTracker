import SwiftData
import SwiftUI

struct ProjectDetailExportSheet: View {
    @Bindable var viewModel: ProjectDetailViewModel

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
        VStack(alignment: .leading, spacing: 20) {
            Text("Projekt exportieren")
                .font(.title)
                .bold()

            Text("\(viewModel.project.displayClientName) - \(viewModel.project.displayName)")
                .font(.headline)
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                Text("Format").font(.headline)

                Picker("Format", selection: $viewModel.exportFormat) {
                    ForEach(ProjectExportFormat.allCases) { format in
                        Text(format.title).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: usesStackedRows ? .infinity : 240)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Inhalt").font(.headline)

                Picker("Inhalt", selection: $viewModel.exportContentMode) {
                    ForEach(viewModel.availableExportModes) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: usesStackedRows ? .infinity : 360)

                if !viewModel.project.hasHourlyRate {
                    Label(
                        "Kostenexport ist erst moeglich, wenn ein Stundensatz hinterlegt ist.",
                        systemImage: "info.circle"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack {
                Spacer()

                Button("Abbrechen", role: .cancel) {
                    viewModel.isPresentingExportSheet = false
                }

#if os(macOS)
                Button("Export starten", action: viewModel.exportProjectData)
                    .buttonStyle(.borderedProminent)
                    .tint(viewModel.project.projectActionColor)
#else
                Button(viewModel.hasPreparedExportForCurrentSelection ? "Neu erstellen" : "Export vorbereiten") {
                    viewModel.exportProjectData()
                }
                .buttonStyle(.bordered)

                if viewModel.hasPreparedExportForCurrentSelection,
                   let preparedExportURL = viewModel.preparedExportURL {
                    ShareLink(item: preparedExportURL) {
                        Label("Export teilen", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(viewModel.project.projectActionColor)
                }
#endif
            }
        }
        .padding(sectionPadding)
#if os(macOS)
        .frame(width: 520)
#else
        .frame(maxWidth: .infinity, alignment: .leading)
#endif
    }
}

#Preview {
    let project = ClientProject.sampleData[0]
    let viewModel = ProjectDetailViewModel(project: project, activeSession: nil)
    viewModel.isPresentingExportSheet = true
    return ProjectDetailExportSheet(viewModel: viewModel)
        .modelContainer(ModelContainer.preview)
}
