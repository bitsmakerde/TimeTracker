import Foundation
import SwiftUI

enum AnalyticsAggregator {
    struct Snapshot {
        let totalDuration: TimeInterval
        let totalValue: Double
        let todayDuration: TimeInterval
        let weekDuration: TimeInterval
        let entryCount: Int
        let projectBars: [ProjectAggregate]
        let weekBars: [WeekBar]
        let day: [DayProfile.HourBucket]
    }

    struct ProjectAggregate {
        let projectId: UUID
        let projectName: String
        let clientName: String
        let color: Color
        let duration: TimeInterval
        let percentage: Double
    }

    static func snapshot(projects: [ClientProject], referenceDate: Date = .now) -> Snapshot {
        let active = projects.filter { !$0.isArchived }

        var totalDuration: TimeInterval = 0
        var totalValue: Double = 0
        var todayDuration: TimeInterval = 0
        var weekDuration: TimeInterval = 0
        var entryCount = 0

        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: referenceDate)
        let endOfToday = min(
            cal.date(byAdding: .day, value: 1, to: startOfToday) ?? referenceDate,
            referenceDate
        )
        let startOfWeek = cal.dateInterval(of: .weekOfYear, for: referenceDate)?.start ?? startOfToday

        var perProject: [UUID: TimeInterval] = [:]

        for project in active {
            for session in project.sessionList {
                let dur = session.duration(referenceDate: referenceDate)
                guard dur > 0 else { continue }
                entryCount += 1
                totalDuration += dur
                totalValue += project.billedAmount(for: dur) ?? 0
                perProject[project.id, default: 0] += dur

                todayDuration += intervalDuration(
                    session,
                    between: startOfToday,
                    and: endOfToday,
                    reference: referenceDate
                )
                weekDuration += intervalDuration(
                    session,
                    between: startOfWeek,
                    and: referenceDate,
                    reference: referenceDate
                )
            }
        }

        // Project bars
        let projectBars: [ProjectAggregate] = active.compactMap { project in
            guard let dur = perProject[project.id], dur > 0 else { return nil }
            return ProjectAggregate(
                projectId: project.id,
                projectName: project.displayName,
                clientName: project.displayClientName,
                color: project.projectAccentColor,
                duration: dur,
                percentage: totalDuration > 0 ? dur / totalDuration : 0
            )
        }
        .sorted { $0.duration > $1.duration }

        // Week bars: 7 days from start of current week
        let weekDays = (0..<7).map { offset -> Date in
            cal.date(byAdding: .day, value: offset, to: startOfWeek) ?? startOfWeek
        }
        let dayLabels = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

        let weekBars: [WeekBar] = weekDays.enumerated().map { idx, day in
            let nextDay = cal.date(byAdding: .day, value: 1, to: day) ?? day
            var parts: [(Color, Double)] = []
            for project in active {
                let mins = project.sessionList.reduce(0.0) { acc, s in
                    acc + intervalMinutes(s, between: day, and: nextDay, reference: referenceDate)
                }
                if mins > 0 {
                    parts.append((project.projectAccentColor, mins))
                }
            }
            let total = parts.reduce(0) { $0 + $1.1 }
            let isToday = cal.isDate(day, inSameDayAs: referenceDate)
            return WeekBar(
                dayLabel: dayLabels[idx],
                dateLabel: String(cal.component(.day, from: day)),
                totalMinutes: total,
                isToday: isToday,
                parts: parts.map { WeekBar.Part(minutes: $0.1, color: $0.0) }
            )
        }

        // Day profile: 24 hourly buckets for today
        let dayBuckets: [DayProfile.HourBucket] = (0..<24).map { hour in
            let hourStart = cal.date(byAdding: .hour, value: hour, to: startOfToday) ?? startOfToday
            let hourEnd = cal.date(byAdding: .hour, value: 1, to: hourStart) ?? hourStart
            var parts: [DayProfile.HourBucket.Part] = []
            for project in active {
                let mins = project.sessionList.reduce(0.0) { acc, s in
                    acc + intervalMinutes(s, between: hourStart, and: hourEnd, reference: referenceDate)
                }
                if mins > 0 {
                    parts.append(.init(minutes: mins, color: project.projectAccentColor))
                }
            }
            return DayProfile.HourBucket(hour: hour, parts: parts)
        }

        return Snapshot(
            totalDuration: totalDuration,
            totalValue: totalValue,
            todayDuration: todayDuration,
            weekDuration: weekDuration,
            entryCount: entryCount,
            projectBars: projectBars,
            weekBars: weekBars,
            day: dayBuckets
        )
    }

    private static func intervalDuration(
        _ session: WorkSession,
        between start: Date,
        and end: Date,
        reference: Date
    ) -> TimeInterval {
        let sessionEnd = session.endedAt ?? reference
        let overlapStart = max(session.startedAt, start)
        let overlapEnd = min(sessionEnd, end)
        return max(overlapEnd.timeIntervalSince(overlapStart), 0)
    }

    private static func intervalMinutes(
        _ session: WorkSession,
        between start: Date,
        and end: Date,
        reference: Date
    ) -> Double {
        let sessionStart = session.startedAt
        let sessionEnd = session.endedAt ?? reference
        let overlapStart = max(sessionStart, start)
        let overlapEnd = min(sessionEnd, end)
        let seconds = max(overlapEnd.timeIntervalSince(overlapStart), 0)
        return seconds / 60
    }
}

#Preview("Analytics snapshot", traits: .fixedLayout(width: 390, height: 760)) {
    let referenceDate = Date.now
    let projects: [ClientProject] = {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: referenceDate)

        func time(hour: Int, minute: Int = 0, dayOffset: Int = 0) -> Date {
            let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) ?? startOfToday
            let hourDate = calendar.date(byAdding: .hour, value: hour, to: day) ?? day
            return calendar.date(byAdding: .minute, value: minute, to: hourDate) ?? hourDate
        }

        let designProject = ClientProject(
            clientName: "Acme Corp",
            name: "Website Redesign",
            hourlyRate: 85,
            accentRed: 0.0,
            accentGreen: 0.48,
            accentBlue: 1.0
        )
        let appProject = ClientProject(
            clientName: "Northwind",
            name: "iOS App",
            hourlyRate: 110,
            accentRed: 0.20,
            accentGreen: 0.78,
            accentBlue: 0.35
        )
        let strategyProject = ClientProject(
            clientName: "Studio Kern",
            name: "Strategie",
            hourlyRate: 95,
            accentRed: 1.0,
            accentGreen: 0.58,
            accentBlue: 0.0
        )

        designProject.sessions = [
            WorkSession(project: designProject, startedAt: time(hour: 8), endedAt: time(hour: 10, minute: 15)),
            WorkSession(project: designProject, startedAt: time(hour: 4, dayOffset: -1), endedAt: time(hour: 7, dayOffset: -1)),
        ]
        appProject.sessions = [
            WorkSession(project: appProject, startedAt: time(hour: 10), endedAt: time(hour: 11, minute: 30)),
            WorkSession(project: appProject, startedAt: time(hour: 14), endedAt: time(hour: 15, minute: 15)),
        ]
        strategyProject.sessions = [
            WorkSession(project: strategyProject, startedAt: time(hour: 13), endedAt: time(hour: 13, minute: 50)),
        ]

        return [designProject, appProject, strategyProject]
    }()
    let snapshot = AnalyticsAggregator.snapshot(projects: projects, referenceDate: referenceDate)

    ScrollView {
        VStack(spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                StatTile("Gesamtzeit", value: TimeFormatting.compactDuration(snapshot.totalDuration))
                StatTile("Gesamtwert", value: TimeFormatting.euroAmount(snapshot.totalValue))
                StatTile("Diese Woche", value: TimeFormatting.compactDuration(snapshot.weekDuration))
                StatTile("Heute", value: TimeFormatting.compactDuration(snapshot.todayDuration))
            }

            SectionCard("Top-Projekte") {
                VStack(spacing: 12) {
                    ForEach(snapshot.projectBars, id: \.projectId) { project in
                        ProjectBar(
                            projectColor: project.color,
                            projectName: project.projectName,
                            clientName: project.clientName,
                            duration: project.duration,
                            percentage: project.percentage
                        )
                    }
                }
            }

            SectionCard("Wochenstunden") {
                WeekBars(bars: snapshot.weekBars)
            }

            SectionCard("Tagesprofil") {
                DayProfile(buckets: snapshot.day)
            }
        }
        .padding()
    }
    .background(TTColors.bg)
}
