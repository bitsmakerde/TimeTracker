import CoreGraphics
import CoreText
import Foundation

enum ProjectExportContentMode: String, CaseIterable, Identifiable {
    case hoursOnly
    case hoursAndCosts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hoursOnly:
            return "Nur Stunden"
        case .hoursAndCosts:
            return "Stunden + Kosten"
        }
    }

    var includesCosts: Bool {
        self == .hoursAndCosts
    }
}

enum ProjectExportFormat: String, CaseIterable, Identifiable {
    case csv
    case pdf

    var id: String { rawValue }

    var title: String {
        switch self {
        case .csv:
            return "CSV"
        case .pdf:
            return "PDF"
        }
    }

    var fileExtension: String {
        rawValue
    }
}

struct ProjectExportDocument {
    let projectName: String
    let clientName: String
    let exportedAt: Date
    let mode: ProjectExportContentMode
    let taskSummaries: [ProjectExportTaskSummary]
    let sessionRows: [ProjectExportSessionRow]
    let totalDuration: TimeInterval
    let totalCost: Double?
}

struct ProjectExportTaskSummary: Identifiable {
    let id: String
    let taskTitle: String
    let duration: TimeInterval
    let cost: Double?
}

struct ProjectExportSessionRow: Identifiable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date?
    let taskTitle: String
    let duration: TimeInterval
    let cost: Double?
}

enum ProjectExportService {
    private enum TaskGroupingKey: Hashable {
        case task(UUID)
        case unassigned
    }

    private struct TaskAggregate {
        var duration: TimeInterval = 0
        var cost: Double = 0
        var hasCost = false
    }

    private static let locale = Locale(identifier: "de_DE")

    static func makeDocument(
        for project: ClientProject,
        mode: ProjectExportContentMode,
        referenceDate: Date
    ) -> ProjectExportDocument {
        let sessions = project.sessions.sorted { $0.startedAt < $1.startedAt }
        let effectiveMode: ProjectExportContentMode = mode.includesCosts && !project.hasHourlyRate ? .hoursOnly : mode

        var rows: [ProjectExportSessionRow] = []
        var aggregates: [TaskGroupingKey: TaskAggregate] = [:]
        var totalDuration: TimeInterval = 0
        var runningTotalCost: Double = 0
        var hasTotalCost = false

        for session in sessions {
            let duration = session.duration(referenceDate: referenceDate)
            let taskKey: TaskGroupingKey = {
                if let taskID = session.task?.id {
                    return .task(taskID)
                }

                return .unassigned
            }()
            let taskTitle = session.task?.displayTitle ?? "Ohne Aufgabe"
            let rowCost = effectiveMode.includesCosts ? project.billedAmount(for: duration) : nil

            rows.append(
                ProjectExportSessionRow(
                    id: session.id,
                    startedAt: session.startedAt,
                    endedAt: session.endedAt,
                    taskTitle: taskTitle,
                    duration: duration,
                    cost: rowCost
                )
            )

            var aggregate = aggregates[taskKey, default: TaskAggregate()]
            aggregate.duration += duration

            if let rowCost {
                aggregate.cost += rowCost
                aggregate.hasCost = true
                runningTotalCost += rowCost
                hasTotalCost = true
            }

            aggregates[taskKey] = aggregate
            totalDuration += duration
        }

        for task in project.sortedTasks {
            let key = TaskGroupingKey.task(task.id)
            if aggregates[key] == nil {
                aggregates[key] = TaskAggregate()
            }
        }

        var orderedKeys: [TaskGroupingKey] = project.sortedTasks.map { .task($0.id) }
        if aggregates[.unassigned] != nil {
            orderedKeys.append(.unassigned)
        }

        for key in aggregates.keys where !orderedKeys.contains(key) {
            orderedKeys.append(key)
        }

        let taskSummaries = orderedKeys.compactMap { key -> ProjectExportTaskSummary? in
            guard let aggregate = aggregates[key] else {
                return nil
            }

            let title: String
            let id: String

            switch key {
            case .task(let taskID):
                if let task = project.tasks.first(where: { $0.id == taskID }) {
                    title = task.displayTitle
                    id = taskID.uuidString
                } else {
                    title = "Aufgabe entfernt"
                    id = taskID.uuidString
                }
            case .unassigned:
                title = "Ohne Aufgabe"
                id = "unassigned"
            }

            return ProjectExportTaskSummary(
                id: id,
                taskTitle: title,
                duration: aggregate.duration,
                cost: aggregate.hasCost ? aggregate.cost : nil
            )
        }

        return ProjectExportDocument(
            projectName: project.displayName,
            clientName: project.displayClientName,
            exportedAt: referenceDate,
            mode: effectiveMode,
            taskSummaries: taskSummaries,
            sessionRows: rows,
            totalDuration: totalDuration,
            totalCost: hasTotalCost ? runningTotalCost : nil
        )
    }

    static func exportData(
        document: ProjectExportDocument,
        format: ProjectExportFormat
    ) -> Data {
        switch format {
        case .csv:
            return csvData(from: document)
        case .pdf:
            return pdfData(from: document)
        }
    }

    static func csvString(from document: ProjectExportDocument) -> String {
        var lines: [String] = []

        lines.append("Projekt;Kunde;Exportiert am;Modus")
        lines.append(
            [
                csvCell(document.projectName),
                csvCell(document.clientName),
                csvCell(document.exportedAt.formatted(date: .abbreviated, time: .shortened)),
                csvCell(document.mode.title),
            ].joined(separator: ";")
        )

        lines.append("")
        lines.append("Aufgaben")

        if document.mode.includesCosts {
            lines.append("Aufgabe;Stunden;Kosten (EUR)")
        } else {
            lines.append("Aufgabe;Stunden")
        }

        for summary in document.taskSummaries {
            if document.mode.includesCosts {
                lines.append(
                    [
                        csvCell(summary.taskTitle),
                        csvCell(formattedHours(summary.duration)),
                        csvCell(formattedCost(summary.cost)),
                    ].joined(separator: ";")
                )
            } else {
                lines.append(
                    [
                        csvCell(summary.taskTitle),
                        csvCell(formattedHours(summary.duration)),
                    ].joined(separator: ";")
                )
            }
        }

        if document.mode.includesCosts {
            lines.append(
                [
                    csvCell("Gesamt"),
                    csvCell(formattedHours(document.totalDuration)),
                    csvCell(formattedCost(document.totalCost)),
                ].joined(separator: ";")
            )
        } else {
            lines.append(
                [
                    csvCell("Gesamt"),
                    csvCell(formattedHours(document.totalDuration)),
                ].joined(separator: ";")
            )
        }

        lines.append("")
        lines.append("Zeiteintraege")

        if document.mode.includesCosts {
            lines.append("Datum;Start;Ende;Aufgabe;Stunden;Kosten (EUR)")
        } else {
            lines.append("Datum;Start;Ende;Aufgabe;Stunden")
        }

        for row in document.sessionRows {
            let rowItems = [
                csvCell(row.startedAt.formatted(date: .abbreviated, time: .omitted)),
                csvCell(row.startedAt.formatted(date: .omitted, time: .shortened)),
                csvCell(row.endedAt?.formatted(date: .omitted, time: .shortened) ?? "Aktiv"),
                csvCell(row.taskTitle),
                csvCell(formattedHours(row.duration)),
            ]

            if document.mode.includesCosts {
                lines.append((rowItems + [csvCell(formattedCost(row.cost))]).joined(separator: ";"))
            } else {
                lines.append(rowItems.joined(separator: ";"))
            }
        }

        return lines.joined(separator: "\n")
    }

    static func csvData(from document: ProjectExportDocument) -> Data {
        Data(csvString(from: document).utf8)
    }

    static func pdfData(from document: ProjectExportDocument) -> Data {
        let text = pdfText(from: document)
        let pageSize = CGSize(width: 595, height: 842)
        let inset: CGFloat = 28
        let drawingRect = CGRect(
            x: inset,
            y: inset,
            width: pageSize.width - (2 * inset),
            height: pageSize.height - (2 * inset)
        )

        let font = CTFontCreateWithName("Menlo" as CFString, 11, nil)
        let attributedString = NSAttributedString(
            string: text,
            attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
            ]
        )
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString as CFAttributedString)

        let mutableData = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: pageSize)

        guard let dataConsumer = CGDataConsumer(data: mutableData as CFMutableData),
              let context = CGContext(consumer: dataConsumer, mediaBox: &mediaBox, nil) else {
            return Data()
        }

        var currentLocation = 0
        let fullLength = attributedString.length

        while currentLocation < fullLength {
            context.beginPDFPage(nil)

            let path = CGMutablePath()
            path.addRect(drawingRect)

            let frame = CTFramesetterCreateFrame(
                framesetter,
                CFRange(location: currentLocation, length: 0),
                path,
                nil
            )
            CTFrameDraw(frame, context)

            let visibleRange = CTFrameGetVisibleStringRange(frame)
            context.endPDFPage()

            if visibleRange.length == 0 {
                break
            }

            currentLocation += visibleRange.length
        }

        context.closePDF()
        return mutableData as Data
    }

    private static func pdfText(from document: ProjectExportDocument) -> String {
        var lines: [String] = []

        lines.append("Projektexport")
        lines.append("Projekt: \(document.projectName)")
        lines.append("Kunde: \(document.clientName)")
        lines.append("Exportiert am: \(document.exportedAt.formatted(date: .abbreviated, time: .shortened))")
        lines.append("Modus: \(document.mode.title)")
        lines.append("")
        lines.append("AUFGABEN")

        if document.mode.includesCosts {
            lines.append("Aufgabe | Stunden | Kosten (EUR)")
        } else {
            lines.append("Aufgabe | Stunden")
        }

        for summary in document.taskSummaries {
            if document.mode.includesCosts {
                lines.append("\(summary.taskTitle) | \(formattedHours(summary.duration)) | \(formattedCost(summary.cost))")
            } else {
                lines.append("\(summary.taskTitle) | \(formattedHours(summary.duration))")
            }
        }

        if document.mode.includesCosts {
            lines.append("Gesamt | \(formattedHours(document.totalDuration)) | \(formattedCost(document.totalCost))")
        } else {
            lines.append("Gesamt | \(formattedHours(document.totalDuration))")
        }

        lines.append("")
        lines.append("ZEITEINTRAEGE")

        if document.mode.includesCosts {
            lines.append("Datum | Start | Ende | Aufgabe | Stunden | Kosten (EUR)")
        } else {
            lines.append("Datum | Start | Ende | Aufgabe | Stunden")
        }

        for row in document.sessionRows {
            let prefix = "\(row.startedAt.formatted(date: .abbreviated, time: .omitted)) | \(row.startedAt.formatted(date: .omitted, time: .shortened)) | \(row.endedAt?.formatted(date: .omitted, time: .shortened) ?? "Aktiv") | \(row.taskTitle) | \(formattedHours(row.duration))"

            if document.mode.includesCosts {
                lines.append("\(prefix) | \(formattedCost(row.cost))")
            } else {
                lines.append(prefix)
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func formattedHours(_ duration: TimeInterval) -> String {
        max(duration / 3600, 0).formatted(
            .number
                .locale(locale)
                .precision(.fractionLength(2))
        )
    }

    private static func formattedCost(_ cost: Double?) -> String {
        guard let cost else {
            return "Offen"
        }

        return max(cost, 0).formatted(
            .number
                .locale(locale)
                .precision(.fractionLength(2))
        )
    }

    private static func csvCell(_ value: String) -> String {
        let shouldQuote = value.contains(";") || value.contains("\n") || value.contains("\"")
        guard shouldQuote else {
            return value
        }

        return "\"\(value.replacing("\"", with: "\"\""))\""
    }
}
