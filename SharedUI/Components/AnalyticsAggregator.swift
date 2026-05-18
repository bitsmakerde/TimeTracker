import Foundation
import SwiftUI

enum AnalyticsAggregator {
    struct Snapshot {
        let rangeTitle: String
        let rangeDescription: String
        let timelineTitle: String
        let totalDuration: TimeInterval
        let totalValue: Double
        let todayDuration: TimeInterval
        let weekDuration: TimeInterval
        let averageDailyDuration: TimeInterval
        let projectCount: Int
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

    struct RangeSelection: Equatable {
        enum Period: String, CaseIterable, Identifiable {
            case week
            case month
            case year
            case custom

            var id: String { rawValue }

            var title: String {
                switch self {
                case .week:
                    return "Woche"
                case .month:
                    return "Monat"
                case .year:
                    return "Jahr"
                case .custom:
                    return "Individuell"
                }
            }

            var segmentTitle: String {
                switch self {
                case .week:
                    return "Woche"
                case .month:
                    return "Monat"
                case .year:
                    return "Jahr"
                case .custom:
                    return "Indiv."
                }
            }
        }

        var period: Period = .week
        var customStart: Date = .now
        var customEnd: Date = .now

        func normalized(calendar: Calendar) -> Self {
            var copy = self
            let start = calendar.startOfDay(for: min(customStart, customEnd))
            let end = calendar.startOfDay(for: max(customStart, customEnd))
            copy.customStart = start
            copy.customEnd = end
            return copy
        }

        func fullInterval(referenceDate: Date, calendar: Calendar) -> DateInterval {
            let normalizedSelection = normalized(calendar: calendar)

            switch normalizedSelection.period {
            case .week:
                if let interval = calendar.dateInterval(of: .weekOfYear, for: referenceDate) {
                    return interval
                }
            case .month:
                if let interval = calendar.dateInterval(of: .month, for: referenceDate) {
                    return interval
                }
            case .year:
                if let interval = calendar.dateInterval(of: .year, for: referenceDate) {
                    return interval
                }
            case .custom:
                let end = calendar.date(
                    byAdding: .day,
                    value: 1,
                    to: normalizedSelection.customEnd
                ) ?? normalizedSelection.customEnd
                return DateInterval(start: normalizedSelection.customStart, end: end)
            }

            return DateInterval(start: referenceDate, end: referenceDate)
        }

        func dataInterval(referenceDate: Date, calendar: Calendar) -> DateInterval {
            let interval = fullInterval(referenceDate: referenceDate, calendar: calendar)
            let end = min(interval.end, referenceDate)
            return DateInterval(start: interval.start, end: max(interval.start, end))
        }

        func rangeDescription(
            referenceDate: Date,
            calendar: Calendar,
            locale: Locale = .current
        ) -> String {
            switch period {
            case .month:
                return referenceDate.formatted(
                    .dateTime
                        .month(.wide)
                        .year()
                        .locale(locale)
                )
                .capitalized
            case .year:
                return referenceDate.formatted(
                    .dateTime
                        .year()
                        .locale(locale)
                )
            case .week, .custom:
                let interval = fullInterval(referenceDate: referenceDate, calendar: calendar)
                let inclusiveEnd = (calendar.date(
                    byAdding: .second,
                    value: -1,
                    to: interval.end
                ) ?? interval.start)
                return shortDate(interval.start, locale: locale) + " – " + shortDate(inclusiveEnd, locale: locale)
            }
        }

        func timelineTitle(referenceDate: Date, calendar: Calendar) -> String {
            switch timelineGranularity(referenceDate: referenceDate, calendar: calendar) {
            case .day:
                switch period {
                case .week:
                    return "Tage dieser Woche"
                case .month:
                    return "Tage dieses Monats"
                case .year:
                    return "Tage dieses Jahres"
                case .custom:
                    return "Tage im Zeitraum"
                }
            case .week:
                return "Wochen im Zeitraum"
            case .month:
                switch period {
                case .year:
                    return "Monate dieses Jahres"
                case .week, .month, .custom:
                    return "Monate im Zeitraum"
                }
            }
        }

        fileprivate func timelineGranularity(
            referenceDate: Date,
            calendar: Calendar
        ) -> TimelineGranularity {
            switch period {
            case .week, .month:
                return .day
            case .year:
                return .month
            case .custom:
                let interval = fullInterval(referenceDate: referenceDate, calendar: calendar)
                let dayCount = AnalyticsAggregator.dayCount(in: interval, calendar: calendar)

                if dayCount <= 31 {
                    return .day
                }

                if dayCount <= 180 {
                    return .week
                }

                return .month
            }
        }

        private func shortDate(_ date: Date, locale: Locale) -> String {
            date.formatted(
                .dateTime
                    .day()
                    .month(.abbreviated)
                    .year()
                    .locale(locale)
            )
        }
    }

    static func snapshot(
        projects: [ClientProject],
        selection: RangeSelection = .init(),
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> Snapshot {
        let normalizedSelection = selection.normalized(calendar: calendar)
        let activeProjects = projects.filter { !$0.isArchived }
        let dataInterval = normalizedSelection.dataInterval(
            referenceDate: referenceDate,
            calendar: calendar
        )

        var totalDuration: TimeInterval = 0
        var totalValue: Double = 0
        var todayDuration: TimeInterval = 0
        var weekDuration: TimeInterval = 0
        var entryCount = 0
        var perProject: [UUID: TimeInterval] = [:]

        let startOfToday = calendar.startOfDay(for: referenceDate)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
        let currentWeekInterval = calendar.dateInterval(of: .weekOfYear, for: referenceDate)
        let currentWeekStart = currentWeekInterval?.start ?? startOfToday
        let currentWeekEnd = currentWeekInterval?.end ?? endOfToday

        for project in activeProjects {
            for session in project.sessionList {
                let selectedDuration = intervalDuration(
                    session,
                    between: dataInterval.start,
                    and: dataInterval.end,
                    reference: referenceDate
                )
                guard selectedDuration > 0 else {
                    continue
                }

                entryCount += 1
                totalDuration += selectedDuration
                totalValue += project.billedAmount(for: selectedDuration) ?? 0
                perProject[project.id, default: 0] += selectedDuration

                todayDuration += intervalDuration(
                    session,
                    between: max(startOfToday, dataInterval.start),
                    and: min(endOfToday, dataInterval.end),
                    reference: referenceDate
                )
                weekDuration += intervalDuration(
                    session,
                    between: max(currentWeekStart, dataInterval.start),
                    and: min(currentWeekEnd, dataInterval.end),
                    reference: referenceDate
                )
            }
        }

        let projectBars: [ProjectAggregate] = activeProjects.compactMap { project in
            guard let duration = perProject[project.id],
                  duration > 0 else {
                return nil
            }

            return ProjectAggregate(
                projectId: project.id,
                projectName: project.displayName,
                clientName: project.displayClientName,
                color: project.projectAccentColor,
                duration: duration,
                percentage: totalDuration > 0 ? duration / totalDuration : 0
            )
        }
        .sorted { $0.duration > $1.duration }

        let weekBars = timelineBuckets(
            for: normalizedSelection,
            referenceDate: referenceDate,
            calendar: calendar
        )
        .map { bucket in
            let bucketStart = max(bucket.start, dataInterval.start)
            let bucketEnd = min(bucket.end, dataInterval.end)

            let parts = activeProjects.compactMap { project -> WeekBar.Part? in
                let minutes = project.sessionList.reduce(0.0) { result, session in
                    result + intervalMinutes(
                        session,
                        between: bucketStart,
                        and: bucketEnd,
                        reference: referenceDate
                    )
                }

                guard minutes > 0 else {
                    return nil
                }

                return WeekBar.Part(minutes: minutes, color: project.projectAccentColor)
            }

            return WeekBar(
                dayLabel: bucket.dayLabel,
                dateLabel: bucket.dateLabel,
                totalMinutes: parts.reduce(0) { $0 + $1.minutes },
                isToday: bucket.isCurrent,
                parts: parts
            )
        }

        let dayBuckets: [DayProfile.HourBucket] = (0..<24).map { hour in
            var parts: [DayProfile.HourBucket.Part] = []

            for project in activeProjects {
                let minutes = project.sessionList.reduce(0.0) { result, session in
                    result + intervalMinutesAcrossSelectedRange(
                        session,
                        hour: hour,
                        dataInterval: dataInterval,
                        calendar: calendar,
                        reference: referenceDate
                    )
                }

                if minutes > 0 {
                    parts.append(.init(minutes: minutes, color: project.projectAccentColor))
                }
            }

            return DayProfile.HourBucket(hour: hour, parts: parts)
        }

        let elapsedDayCount = dayCount(in: dataInterval, calendar: calendar)
        let averageDailyDuration = elapsedDayCount > 0
            ? totalDuration / Double(elapsedDayCount)
            : 0

        return Snapshot(
            rangeTitle: normalizedSelection.period.title,
            rangeDescription: normalizedSelection.rangeDescription(
                referenceDate: referenceDate,
                calendar: calendar,
                locale: calendar.locale ?? .current
            ),
            timelineTitle: normalizedSelection.timelineTitle(
                referenceDate: referenceDate,
                calendar: calendar
            ),
            totalDuration: totalDuration,
            totalValue: totalValue,
            todayDuration: todayDuration,
            weekDuration: weekDuration,
            averageDailyDuration: averageDailyDuration,
            projectCount: projectBars.count,
            entryCount: entryCount,
            projectBars: projectBars,
            weekBars: weekBars,
            day: dayBuckets
        )
    }

    private static func timelineBuckets(
        for selection: RangeSelection,
        referenceDate: Date,
        calendar: Calendar
    ) -> [TimelineBucket] {
        let locale = calendar.locale ?? .current
        let interval = selection.fullInterval(referenceDate: referenceDate, calendar: calendar)

        switch selection.timelineGranularity(referenceDate: referenceDate, calendar: calendar) {
        case .day:
            let dayCount = dayCount(in: interval, calendar: calendar)

            return (0..<dayCount).compactMap { offset in
                let start = calendar.date(byAdding: .day, value: offset, to: interval.start)
                let end = start.flatMap { calendar.date(byAdding: .day, value: 1, to: $0) }
                guard let start,
                      let end else {
                    return nil
                }

                return TimelineBucket(
                    start: start,
                    end: end,
                    dayLabel: shortWeekday(for: start, locale: locale),
                    dateLabel: calendar.component(.day, from: start).formatted(.number.locale(locale)),
                    isCurrent: calendar.isDate(start, inSameDayAs: referenceDate)
                )
            }
        case .week:
            var buckets: [TimelineBucket] = []
            var currentStart = interval.start

            while currentStart < interval.end {
                let weekInterval = calendar.dateInterval(of: .weekOfYear, for: currentStart)
                let start = max(weekInterval?.start ?? currentStart, interval.start)
                let end = min(weekInterval?.end ?? currentStart, interval.end)

                let weekOfYear = calendar.component(.weekOfYear, from: start)
                buckets.append(
                    TimelineBucket(
                        start: start,
                        end: end,
                        dayLabel: "W\(weekOfYear)",
                        dateLabel: calendar.component(.day, from: start).formatted(.number.locale(locale)),
                        isCurrent: start <= referenceDate && referenceDate < end
                    )
                )

                currentStart = end
            }

            return buckets
        case .month:
            var buckets: [TimelineBucket] = []
            var currentStart = interval.start

            while currentStart < interval.end {
                let monthInterval = calendar.dateInterval(of: .month, for: currentStart)
                let start = max(monthInterval?.start ?? currentStart, interval.start)
                let end = min(monthInterval?.end ?? currentStart, interval.end)

                buckets.append(
                    TimelineBucket(
                        start: start,
                        end: end,
                        dayLabel: shortMonth(for: start, locale: locale),
                        dateLabel: "",
                        isCurrent: calendar.isDate(start, equalTo: referenceDate, toGranularity: .month)
                    )
                )

                currentStart = end
            }

            return buckets
        }
    }

    static func dayCount(
        in interval: DateInterval,
        calendar: Calendar
    ) -> Int {
        guard interval.duration > 0 else {
            return 0
        }

        let startOfDay = calendar.startOfDay(for: interval.start)
        let inclusiveEnd = calendar.date(byAdding: .second, value: -1, to: interval.end) ?? interval.start
        let endOfDay = calendar.startOfDay(for: inclusiveEnd)
        let dayDifference = calendar.dateComponents([.day], from: startOfDay, to: endOfDay).day ?? 0
        return dayDifference + 1
    }

    private static func shortWeekday(
        for date: Date,
        locale: Locale
    ) -> String {
        date.formatted(
            .dateTime
                .weekday(.abbreviated)
                .locale(locale)
        )
        .replacing(".", with: "")
    }

    private static func shortMonth(
        for date: Date,
        locale: Locale
    ) -> String {
        date.formatted(
            .dateTime
                .month(.abbreviated)
                .locale(locale)
        )
        .replacing(".", with: "")
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
        let seconds = intervalDuration(
            session,
            between: start,
            and: end,
            reference: reference
        )
        return seconds / 60
    }

    private static func intervalMinutesAcrossSelectedRange(
        _ session: WorkSession,
        hour: Int,
        dataInterval: DateInterval,
        calendar: Calendar,
        reference: Date
    ) -> Double {
        guard dataInterval.duration > 0 else {
            return 0
        }

        let startDay = calendar.startOfDay(for: dataInterval.start)
        let dayCount = dayCount(in: dataInterval, calendar: calendar)

        return (0..<dayCount).reduce(0.0) { result, dayOffset in
            let day = calendar.date(byAdding: .day, value: dayOffset, to: startDay) ?? startDay
            let hourStart = calendar.date(byAdding: .hour, value: hour, to: day) ?? day
            let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart) ?? hourStart
            let intervalStart = max(hourStart, dataInterval.start)
            let intervalEnd = min(hourEnd, dataInterval.end)

            guard intervalStart < intervalEnd else {
                return result
            }

            return result + intervalMinutes(
                session,
                between: intervalStart,
                and: intervalEnd,
                reference: reference
            )
        }
    }

    private struct TimelineBucket {
        let start: Date
        let end: Date
        let dayLabel: String
        let dateLabel: String
        let isCurrent: Bool
    }

    fileprivate enum TimelineGranularity {
        case day
        case week
        case month
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
    let snapshot = AnalyticsAggregator.snapshot(
        projects: projects,
        selection: .init(period: .week),
        referenceDate: referenceDate
    )

    ScrollView {
        VStack(spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                StatTile("Gesamtzeit", value: TimeFormatting.compactDuration(snapshot.totalDuration))
                StatTile("Gesamtwert", value: TimeFormatting.euroAmount(snapshot.totalValue))
                StatTile("Einträge", value: snapshot.entryCount.formatted(.number))
                StatTile("Ø pro Tag", value: TimeFormatting.compactDuration(snapshot.averageDailyDuration))
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

            SectionCard(snapshot.timelineTitle) {
                WeekBars(bars: snapshot.weekBars)
            }

            SectionCard("Tagesprofil im Zeitraum") {
                DayProfile(buckets: snapshot.day)
            }
        }
        .padding()
    }
    .background(TTColors.bg)
}
