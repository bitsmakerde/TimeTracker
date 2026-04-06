import Foundation

enum ProjectExportFileNaming {
    static func defaultFileName(
        projectName: String,
        format: ProjectExportFormat,
        date: Date = .now
    ) -> String {
        let safeProjectName = sanitizedFileNameComponent(projectName)
        let dateStamp = date.formatted(
            .iso8601
                .year()
                .month()
                .day()
        )

        return "\(safeProjectName)-Export-\(dateStamp).\(format.fileExtension)"
    }

    static func sanitizedFileNameComponent(_ value: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
        let components = value
            .components(separatedBy: invalidCharacters)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let cleaned = components.joined(separator: "-")

        if cleaned.isEmpty {
            return "Projekt"
        }

        return cleaned
    }
}
