import SwiftUI

struct ProjectCreationDraft {
    var clientName: String
    var projectName: String
    var notes: String
    var hourlyRateText: String
    var usesCustomProjectColor: Bool
    var projectColor: Color

    init(initialClientName: String = "") {
        self.clientName = initialClientName
        self.projectName = ""
        self.notes = ""
        self.hourlyRateText = ""
        self.usesCustomProjectColor = false
        self.projectColor = .teal
    }

    var parsedHourlyRate: Double? {
        TimeFormatting.parseDecimalInput(hourlyRateText)
    }

    var hasInvalidHourlyRate: Bool {
        let trimmed = hourlyRateText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return false
        }

        guard let parsedHourlyRate else {
            return true
        }

        return parsedHourlyRate < 0
    }

    var canSave: Bool {
        !projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !hasInvalidHourlyRate
    }

    func makeProject() -> ClientProject? {
        guard canSave else {
            return nil
        }

        let project = ClientProject(
            clientName: clientName,
            name: projectName,
            notes: notes,
            hourlyRate: parsedHourlyRate
        )

        if usesCustomProjectColor {
            project.setCustomAccentColor(projectColor)
        }

        return project
    }
}
