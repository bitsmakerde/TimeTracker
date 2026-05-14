import SwiftUI

struct ClientSwitcher: View {
    struct Item: Identifiable {
        let id: UUID
        let clientName: String
        let projectName: String
        let projectColor: Color
        let isRunning: Bool
    }

    let items: [Item]
    let selectedId: UUID?
    let onSelect: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(items) { item in
                    Button {
                        onSelect(item.id)
                    } label: {
                        chip(for: item, selected: item.id == selectedId)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
    }

    private func chip(for item: Item, selected: Bool) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(item.clientName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(TTColors.text2)
                Text(item.projectName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TTColors.text)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: TTRadius.md, style: .continuous)
                .fill(TTColors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: TTRadius.md, style: .continuous)
                .strokeBorder(selected ? item.projectColor : TTColors.text4, lineWidth: selected ? 2.5 : 0.5)
        )
        .shadow(
            color: selected ? item.projectColor.opacity(0.25) : .clear,
            radius: selected ? 2 : 0,
            y: selected ? 1.5 : 0
        )
    }
}

#Preview {
    let isActiveUUID = UUID()
    ClientSwitcher(
        items: [
            .init(id: isActiveUUID, clientName: "Client A", projectName: "Projekt Alpha", projectColor: .blue, isRunning: true),
            .init(id: UUID(), clientName: "Client B", projectName: "Projekt Beta", projectColor: .green, isRunning: false),
            .init(id: UUID(), clientName: "Client C", projectName: "Projekt Gamma", projectColor: .orange, isRunning: false)
        ],
        selectedId: isActiveUUID,
        onSelect: { _ in }
    )
    .padding()
}
