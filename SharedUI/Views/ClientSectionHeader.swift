import SwiftUI

struct ClientSectionHeader: View {
    let title: String
    let onAddProject: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(.caption.weight(.semibold))

            Spacer()

            Button(action: onAddProject) {
                Image(systemName: "plus")
                    .font(.caption.weight(.bold))
            }
            .buttonStyle(.borderless)
            .help("Projekt zu diesem Kunden hinzufuegen")
        }
    }
}
