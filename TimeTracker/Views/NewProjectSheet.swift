import SwiftUI

struct NewProjectSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var clientName: String
    @State private var projectName = ""
    @State private var notes = ""
    @State private var hourlyRateText = ""
    @State private var usesCustomProjectColor = false
    @State private var projectColor = Color.teal

    let onSave: (ClientProject) -> Bool

    init(
        initialClientName: String = "",
        onSave: @escaping (ClientProject) -> Bool
    ) {
        _clientName = State(initialValue: initialClientName)
        self.onSave = onSave
    }

    private var parsedHourlyRate: Double? {
        TimeFormatting.parseDecimalInput(hourlyRateText)
    }

    private var hasInvalidHourlyRate: Bool {
        let trimmed = hourlyRateText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return false
        }

        guard let parsedHourlyRate else {
            return true
        }

        return parsedHourlyRate < 0
    }

    private var canSave: Bool {
        !projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !hasInvalidHourlyRate
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Neues Kundenprojekt")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text("Lege ein Projekt an, damit du die Arbeitszeit direkt starten und spaeter gruppiert auswerten kannst.")
                .foregroundStyle(.secondary)

            Form {
                TextField("Kunde", text: $clientName)
                TextField("Projektname", text: $projectName)
                TextField("Stundensatz in EUR", text: $hourlyRateText)

                Toggle("Eigene Projektfarbe verwenden", isOn: $usesCustomProjectColor)

                if usesCustomProjectColor {
                    ColorPicker(
                        "Projektfarbe",
                        selection: $projectColor,
                        supportsOpacity: false
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Notiz")
                        .font(.subheadline.weight(.medium))

                    TextEditor(text: $notes)
                        .frame(minHeight: 120)
                }
            }
            .formStyle(.grouped)

            if hasInvalidHourlyRate {
                Text("Bitte gib einen gueltigen nicht-negativen Stundensatz ein.")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            } else {
                Text("Leer lassen, wenn du den Stundensatz spaeter eintragen moechtest.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()

                Button("Abbrechen", role: .cancel) {
                    dismiss()
                }

                Button("Projekt speichern") {
                    let project = ClientProject(
                        clientName: clientName,
                        name: projectName,
                        notes: notes,
                        hourlyRate: parsedHourlyRate
                    )

                    if usesCustomProjectColor {
                        project.setCustomAccentColor(projectColor)
                    }

                    if onSave(project) {
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(ClientProject.primaryActionColor)
                .disabled(!canSave)
            }
        }
        .padding(24)
#if os(macOS)
        .frame(width: 460)
#else
        .frame(maxWidth: .infinity, alignment: .leading)
#endif
    }
}
