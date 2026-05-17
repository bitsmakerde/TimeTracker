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

    @State private var topProjectsMode: TopMode = .bars

    enum TopMode: String, CaseIterable, Identifiable {
        case bars, pie
        var id: String { rawValue }
        var title: String {
            switch self {
            case .bars: return "Balken"
            case .pie: return "Kreis"
            }
        }
    }

    private var snapshot: AnalyticsAggregator.Snapshot {
        AnalyticsAggregator.snapshot(projects: projects)
    }

    var body: some View {
        let s = snapshot

        ScrollView {
            VStack(spacing: 14) {
                SyncBanner(syncStatus: trackingStatus.syncStatus)
                introHeader(snapshot: s)
                kpiGrid(snapshot: s)
                topProjectsSection(snapshot: s)
                weekSection(snapshot: s)
                daySection(snapshot: s)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(TTColors.bg.ignoresSafeArea())
        .navigationTitle("Auswertung")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func introHeader(snapshot: AnalyticsAggregator.Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Auswertungen")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(TTColors.text)
            Text("Übersicht über Zeiten, Werte und Verteilung")
                .font(.system(size: 13))
                .foregroundStyle(TTColors.text2)
            HStack(spacing: 6) {
                Image(systemName: "folder")
                Text("\(projects.filter { !$0.isArchived }.count) Projekte · \(snapshot.entryCount) Einträge")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(TTColors.text2)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(TTColors.fill3))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .ttSurface(cornerRadius: TTRadius.lg)
    }

    private func kpiGrid(snapshot s: AnalyticsAggregator.Snapshot) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            StatTile("Gesamtzeit", value: TimeFormatting.compactDuration(s.totalDuration))
            StatTile("Gesamtwert", value: TimeFormatting.euroAmount(s.totalValue))
            StatTile("Diese Woche", value: TimeFormatting.compactDuration(s.weekDuration))
            StatTile("Heute", value: TimeFormatting.compactDuration(s.todayDuration))
        }
    }

    private func topProjectsSection(snapshot s: AnalyticsAggregator.Snapshot) -> some View {
        SectionCard("Top-Projekte") {
            Picker("Modus", selection: $topProjectsMode) {
                ForEach(TopMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        } content: {
            VStack(spacing: 12) {
                if s.projectBars.isEmpty {
                    Text("Noch keine Daten")
                        .font(.system(size: 13))
                        .foregroundStyle(TTColors.text2)
                        .padding(.vertical, 8)
                } else {
                    switch topProjectsMode {
                    case .bars:
                        ForEach(Array(s.projectBars.prefix(8)), id: \.projectId) { agg in
                            ProjectBar(
                                projectColor: agg.color,
                                projectName: agg.projectName,
                                clientName: agg.clientName,
                                duration: agg.duration,
                                percentage: agg.percentage
                            )
                        }
                    case .pie:
                        pieChart(s.projectBars)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func pieChart(_ aggs: [AnalyticsAggregator.ProjectAggregate]) -> some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                ForEach(Array(pieSlices(aggs).enumerated()), id: \.offset) { _, slice in
                    Circle()
                        .trim(from: slice.start, to: slice.end)
                        .stroke(slice.color, lineWidth: 18)
                        .rotationEffect(.degrees(-90))
                }
            }
            .frame(width: 120, height: 120)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(aggs.prefix(5)), id: \.projectId) { agg in
                    HStack(spacing: 6) {
                        Circle().fill(agg.color).frame(width: 8, height: 8)
                        Text(agg.projectName)
                            .font(.system(size: 12))
                            .foregroundStyle(TTColors.text)
                            .lineLimit(1)
                        Spacer()
                        Text(String(format: "%.0f%%", agg.percentage * 100))
                            .font(.ttMono)
                            .font(.system(size: 12))
                            .foregroundStyle(TTColors.text2)
                    }
                }
            }
        }
    }

    private struct PieSlice { let start: CGFloat; let end: CGFloat; let color: Color }
    private func pieSlices(_ aggs: [AnalyticsAggregator.ProjectAggregate]) -> [PieSlice] {
        var acc: CGFloat = 0
        return aggs.map { agg in
            let length = CGFloat(agg.percentage)
            let slice = PieSlice(start: acc, end: acc + length, color: agg.color)
            acc += length
            return slice
        }
    }

    private func weekSection(snapshot s: AnalyticsAggregator.Snapshot) -> some View {
        SectionCard("Wochenstunden") {
            WeekBars(bars: s.weekBars)
        }
    }

    private func daySection(snapshot s: AnalyticsAggregator.Snapshot) -> some View {
        SectionCard("Tagesprofil") {
            DayProfile(buckets: s.day)
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
