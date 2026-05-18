import SwiftData
import SwiftUI

struct AnalyticsScreen: View {
    let trackingStatus: TrackingStatusStore

    @Query(
        sort: [
            SortDescriptor(\ClientProject.clientName),
            SortDescriptor(\ClientProject.name),
        ]
    )
    private var projects: [ClientProject]

    @State private var rangeSelection = AnalyticsAggregator.RangeSelection()
    @State private var topProjectsMode: TopMode = .bars

    enum TopMode: String, CaseIterable, Identifiable {
        case bars
        case pie

        var id: String { rawValue }

        var title: String {
            switch self {
            case .bars:
                return "Balken"
            case .pie:
                return "Kreis"
            }
        }
    }

    private var snapshot: AnalyticsAggregator.Snapshot {
        AnalyticsAggregator.snapshot(
            projects: projects,
            selection: rangeSelection
        )
    }

    var body: some View {
        let snapshot = snapshot

        ScrollView {
            VStack(spacing: 14) {
                SyncBanner(syncStatus: trackingStatus.syncStatus)
                header(snapshot: snapshot)
                kpiGrid(snapshot: snapshot)
                topProjectsSection(snapshot: snapshot)
                timelineSection(snapshot: snapshot)
                daySection(snapshot: snapshot)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(TTColors.bg.ignoresSafeArea())
        .navigationTitle("Auswertung")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: rangeSelection.customStart, initial: false) { _, newValue in
            if newValue > rangeSelection.customEnd {
                rangeSelection.customEnd = newValue
            }
        }
        .onChange(of: rangeSelection.customEnd, initial: false) { _, newValue in
            if newValue < rangeSelection.customStart {
                rangeSelection.customStart = newValue
            }
        }
    }

    private func header(snapshot: AnalyticsAggregator.Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Auswertungen")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(TTColors.text)
                Text("Zeiten, Werte und Verteilung nach Zeitraum.")
                    .font(.system(size: 13))
                    .foregroundStyle(TTColors.text2)
            }

            HStack(spacing: 6) {
                Image(systemName: "calendar")
                Text("\(snapshot.rangeTitle) · \(snapshot.rangeDescription)")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(TTColors.text2)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(TTColors.fill3, in: Capsule())

            HStack(spacing: 6) {
                Image(systemName: "folder")
                Text("\(snapshot.projectCount) Projekte · \(snapshot.entryCount) Einträge")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(TTColors.text2)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(TTColors.fill3, in: Capsule())

            Picker("Zeitraum", selection: $rangeSelection.period) {
                ForEach(AnalyticsAggregator.RangeSelection.Period.allCases) { period in
                    Text(period.segmentTitle).tag(period)
                }
            }
            .pickerStyle(.segmented)

            if rangeSelection.period == .custom {
                VStack(spacing: 10) {
                    DatePicker(
                        "Von",
                        selection: $rangeSelection.customStart,
                        in: ...Date.now,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)

                    DatePicker(
                        "Bis",
                        selection: $rangeSelection.customEnd,
                        in: ...Date.now,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .ttSurface(cornerRadius: TTRadius.lg)
    }

    private func kpiGrid(snapshot: AnalyticsAggregator.Snapshot) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
            ],
            spacing: 10
        ) {
            StatTile("Gesamtzeit", value: TimeFormatting.compactDuration(snapshot.totalDuration))
            StatTile("Gesamtwert", value: TimeFormatting.euroAmount(snapshot.totalValue))
            StatTile(
                "Einträge",
                value: snapshot.entryCount.formatted(.number),
                sub: "\(snapshot.projectCount) Projekte"
            )
            StatTile(
                "Ø pro Tag",
                value: TimeFormatting.compactDuration(snapshot.averageDailyDuration),
                sub: snapshot.rangeDescription
            )
        }
    }

    private func topProjectsSection(snapshot: AnalyticsAggregator.Snapshot) -> some View {
        SectionCard("Top-Projekte") {
            Picker("Modus", selection: $topProjectsMode) {
                ForEach(TopMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        } content: {
            VStack(spacing: 12) {
                if snapshot.projectBars.isEmpty {
                    Text("Noch keine Daten im gewählten Zeitraum")
                        .font(.system(size: 13))
                        .foregroundStyle(TTColors.text2)
                        .padding(.vertical, 8)
                } else {
                    switch topProjectsMode {
                    case .bars:
                        ForEach(snapshot.projectBars.prefix(8), id: \.projectId) { aggregate in
                            ProjectBar(
                                projectColor: aggregate.color,
                                projectName: aggregate.projectName,
                                clientName: aggregate.clientName,
                                duration: aggregate.duration,
                                percentage: aggregate.percentage
                            )
                        }
                    case .pie:
                        pieChart(snapshot.projectBars)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func pieChart(_ aggregates: [AnalyticsAggregator.ProjectAggregate]) -> some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                ForEach(pieSlices(aggregates).enumerated(), id: \.offset) { _, slice in
                    Circle()
                        .trim(from: slice.start, to: slice.end)
                        .stroke(slice.color, lineWidth: 18)
                        .rotationEffect(.degrees(-90))
                }
            }
            .frame(width: 120, height: 120)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(aggregates.prefix(5), id: \.projectId) { aggregate in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(aggregate.color)
                            .frame(width: 8, height: 8)
                        Text(aggregate.projectName)
                            .font(.system(size: 12))
                            .foregroundStyle(TTColors.text)
                            .lineLimit(1)
                        Spacer()
                        Text(aggregate.percentage, format: .percent.precision(.fractionLength(0)))
                            .font(.ttMono)
                            .font(.system(size: 12))
                            .foregroundStyle(TTColors.text2)
                    }
                }
            }
        }
    }

    private func timelineSection(snapshot: AnalyticsAggregator.Snapshot) -> some View {
        SectionCard(snapshot.timelineTitle) {
            WeekBars(bars: snapshot.weekBars)
        }
    }

    private func daySection(snapshot: AnalyticsAggregator.Snapshot) -> some View {
        SectionCard("Tagesprofil im Zeitraum") {
            DayProfile(buckets: snapshot.day)
        }
    }

    private struct PieSlice {
        let start: CGFloat
        let end: CGFloat
        let color: Color
    }

    private func pieSlices(_ aggregates: [AnalyticsAggregator.ProjectAggregate]) -> [PieSlice] {
        var currentStart: CGFloat = 0

        return aggregates.map { aggregate in
            let sliceLength = CGFloat(aggregate.percentage)
            let slice = PieSlice(
                start: currentStart,
                end: currentStart + sliceLength,
                color: aggregate.color
            )
            currentStart += sliceLength
            return slice
        }
    }
}

#Preview("Analytics screen") {
    NavigationStack {
        AnalyticsScreenPreviewHost()
    }
}

@MainActor
private struct AnalyticsScreenPreviewHost: View {
    private let preview = PreviewWorkspaceSnapshot()

    var body: some View {
        AnalyticsScreen(trackingStatus: preview.trackingStatus)
            .modelContainer(preview.modelContainer)
    }
}
