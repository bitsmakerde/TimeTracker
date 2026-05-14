import SwiftUI

struct NewProjectSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft: ProjectCreationDraft

    let onSave: (ClientProject) -> Bool

    init(
        initialClientName: String = "",
        onSave: @escaping (ClientProject) -> Bool
    ) {
        _draft = State(initialValue: ProjectCreationDraft(initialClientName: initialClientName))
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Neues Kundenprojekt")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text("Lege ein Projekt an, damit du die Arbeitszeit direkt starten und spaeter gruppiert auswerten kannst.")
                .foregroundStyle(.secondary)

            Form {
                TextField("Kunde", text: $draft.clientName)
                TextField("Projektname", text: $draft.projectName)
                TextField("Stundensatz in EUR", text: $draft.hourlyRateText)

                Toggle("Eigene Projektfarbe verwenden", isOn: $draft.usesCustomProjectColor)

                if draft.usesCustomProjectColor {
                    ColorPicker(
                        "Projektfarbe",
                        selection: $draft.projectColor,
                        supportsOpacity: false
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Notiz")
                        .font(.subheadline.weight(.medium))

                    TextEditor(text: $draft.notes)
                        .frame(minHeight: 120)
                }
            }
            .formStyle(.grouped)

            if draft.hasInvalidHourlyRate {
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
                    guard let project = draft.makeProject() else {
                        return
                    }

                    if onSave(project) {
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(ClientProject.primaryActionColor)
                .disabled(!draft.canSave)
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

#Preview("New project sheet") {
    NavigationStack {
        NewProjectSheet(initialClientName: "Acme Corp") { _ in true }
    }
    .frame(width: 520, height: 640)
}
