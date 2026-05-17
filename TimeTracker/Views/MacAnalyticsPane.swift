import SwiftUI
import UniformTypeIdentifiers
#if canImport(AppKit)
import AppKit
#endif

struct MacAuswertungPane: View {
    let projects: [ClientProject]
    let lastSyncedAt: Date?

    @State private var topMode: AnalyticsTopProjectsDisplayMode = .bar
    @State private var exportErrorMessage: String?

    private var snapshot: AnalyticsAggregator.Snapshot {
        AnalyticsAggregator.snapshot(projects: projects)
    }

    var body: some View {
        let snapshot = snapshot
        ScrollView {
            VStack(spacing: 14) {
                SyncBanner(lastSyncedAt: lastSyncedAt)
                header
                kpiGrid(snapshot)
                topProjects(snapshot)
                HStack(alignment: .top, spacing: 14) {
                    weekCard(snapshot).frame(maxWidth: .infinity)
                    dayCard(snapshot).frame(maxWidth: .infinity)
                }
            }
            .padding(TTSpacing.lg)
        }
        .alert("Export fehlgeschlagen", isPresented: exportAlertIsPresented) {
            Button("OK", role: .cancel) {
                exportErrorMessage = nil
            }
        } message: {
            Text(exportErrorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: TTSpacing.xl) {
            VStack(alignment: .leading, spacing: TTSpacing.xs) {
                Text("Auswertungen")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(TTColors.text)
                Text("Top-Projekte, Wochenstunden und tägliche Arbeitsverteilung auf einen Blick.")
                    .font(.subheadline)
                    .foregroundStyle(TTColors.text2)
            }
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "calendar").font(.caption)
                Text(monthLabel).font(.caption.bold())
            }
            .foregroundStyle(TTColors.text)
            .padding(.horizontal, TTSpacing.md)
            .padding(.vertical, 6)
            .background(TTColors.fill3, in: Capsule())

            Menu {
                ForEach(AnalyticsExportService.supportedFormats) { format in
                    Button {
                        exportAnalytics(as: format)
                    } label: {
                        Label(format.title, systemImage: exportSystemImage(for: format))
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down").font(.caption)
                    Text("Exportieren").font(.caption.bold())
                }
                .foregroundStyle(TTColors.text)
                .padding(.horizontal, TTSpacing.md)
                .padding(.vertical, 6)
                .background(TTColors.fill3, in: Capsule())
            }
#if os(macOS)
            .menuStyle(.borderlessButton)
#endif
        }
        .padding(TTSpacing.xl)
        .ttSurface(cornerRadius: TTRadius.lg)
    }

    private var monthLabel: String {
        Date.now.formatted(
            .dateTime
                .month(.wide)
                .year()
                .locale(Locale(identifier: "de_DE"))
        )
        .capitalized
    }

    private func kpiGrid(_ snapshot: AnalyticsAggregator.Snapshot) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
            StatTile("Gesamtzeit", value: TimeFormatting.compactDuration(snapshot.totalDuration), sub: "\(snapshot.entryCount) Einträge")
            StatTile("Gesamtwert", value: TimeFormatting.euroAmount(snapshot.totalValue), sub: "aus Zeit × Satz")
            StatTile("Diese Woche", value: TimeFormatting.compactDuration(snapshot.weekDuration))
            StatTile("Heute", value: TimeFormatting.compactDuration(snapshot.todayDuration), sub: "Seit 00:00")
        }
    }

    private func topProjects(_ snapshot: AnalyticsAggregator.Snapshot) -> some View {
        SectionCard("Top-Projekte und Zeitverteilung") {
            HStack(spacing: TTSpacing.sm) {
                Text("Darstellung")
                    .font(.caption)
                    .foregroundStyle(TTColors.text3)
                Picker("", selection: $topMode) {
                    ForEach(AnalyticsTopProjectsDisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }
        } content: {
            switch topMode.presentation(for: snapshot.projectBars) {
            case .empty:
                Text("Noch keine Daten")
                    .font(.subheadline)
                    .foregroundStyle(TTColors.text2)
                    .padding(.vertical, TTSpacing.sm)
            case .bars(let projectBars):
                VStack(spacing: TTSpacing.md) {
                    ForEach(projectBars, id: \.projectId) { aggregate in
                        ProjectBar(
                            projectColor: aggregate.color,
                            projectName: aggregate.projectName,
                            clientName: aggregate.clientName,
                            duration: aggregate.duration,
                            percentage: aggregate.percentage
                        )
                    }
                }
            case .pie(let projectBars):
                MacAnalyticsTopProjectsPieChart(projects: projectBars)
            }
        }
    }

    private var exportAlertIsPresented: Binding<Bool> {
        Binding(
            get: { exportErrorMessage != nil },
            set: { isPresented in
                if isPresented == false {
                    exportErrorMessage = nil
                }
            }
        )
    }

    private func exportSystemImage(for format: ProjectExportFormat) -> String {
        switch format {
        case .csv:
            return "tablecells"
        case .pdf:
            return "doc.richtext"
        }
    }

    private func exportAnalytics(as format: ProjectExportFormat) {
        let exportData = AnalyticsExportService.exportData(
            snapshot: snapshot,
            format: format,
            exportedAt: .now
        )

        guard exportData.isEmpty == false else {
            exportErrorMessage = "Der Export konnte nicht erstellt werden."
            return
        }

#if os(macOS)
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.allowedContentTypes = [utType(for: format)]
        panel.nameFieldStringValue = AnalyticsExportService.defaultFileName(
            for: format,
            exportedAt: .now
        )

        guard panel.runModal() == .OK,
              let destinationURL = panel.url else {
            return
        }

        do {
            try exportData.write(to: destinationURL, options: .atomic)
        } catch {
            exportErrorMessage = "Die Exportdatei konnte nicht gespeichert werden."
        }
#endif
    }

    private func utType(for format: ProjectExportFormat) -> UTType {
        switch format {
        case .csv:
            return .commaSeparatedText
        case .pdf:
            return .pdf
        }
    }

    private func weekCard(_ snapshot: AnalyticsAggregator.Snapshot) -> some View {
        SectionCard("Wochenstunden nach Projekten") {
            WeekBars(bars: snapshot.weekBars).frame(height: 180)
        }
    }

    private func dayCard(_ snapshot: AnalyticsAggregator.Snapshot) -> some View {
        SectionCard("Tagesprofil 0–24 Uhr") {
            DayProfile(buckets: snapshot.day)
        }
    }
}

private struct MacAnalyticsTopProjectsPieChart: View {
    let projects: [AnalyticsAggregator.ProjectAggregate]

    var body: some View {
        HStack(alignment: .center, spacing: TTSpacing.xl) {
            ZStack {
                ForEach(Array(pieSlices.enumerated()), id: \.offset) { _, slice in
                    Circle()
                        .trim(from: slice.start, to: slice.end)
                        .stroke(slice.color, lineWidth: 24)
                        .rotationEffect(.degrees(-90))
                }
            }
            .frame(width: 170, height: 170)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(projects.prefix(6), id: \.projectId) { project in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(project.color)
                            .frame(width: 10, height: 10)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(project.projectName)
                                .font(.headline)
                                .lineLimit(1)

                            Text(project.clientName)
                                .font(.caption)
                                .foregroundStyle(TTColors.text3)
                                .lineLimit(1)
                        }

                        Spacer(minLength: TTSpacing.sm)

                        Text(project.percentage, format: .percent.precision(.fractionLength(0)))
                            .font(.ttMono)
                            .font(.caption)
                            .foregroundStyle(TTColors.text2)
                    }
                }
            }
        }
    }

    private var pieSlices: [PieSlice] {
        var start: CGFloat = 0

        return projects.map { project in
            let end = start + CGFloat(project.percentage)
            let slice = PieSlice(start: start, end: end, color: project.color)
            start = end
            return slice
        }
    }

    private struct PieSlice {
        let start: CGFloat
        let end: CGFloat
        let color: Color
    }
}
