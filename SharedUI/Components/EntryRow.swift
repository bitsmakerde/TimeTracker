import SwiftUI

struct EntryRow: View {
    let startEnd: String
    let projectColor: Color
    let taskName: String
    let clientName: String
    let projectName: String
    let duration: TimeInterval
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text(startEnd)
                    .font(.ttMonoTitle(14))
                    .monospacedDigit()
                    .foregroundStyle(TTColors.text2)
                    .frame(width: 120, alignment: .leading)

                Text(taskName)
                    .font(.ttMonoTitle(15))
                    .foregroundStyle(TTColors.text)
                    .lineLimit(1)

                Spacer(minLength: 4)
                Text(TimeFormatting.compactDuration(duration))
                    .font(.ttMono)
                    .monospacedDigit()
                    .foregroundStyle(TTColors.text)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview("Entry rows", traits: .fixedLayout(width: 390, height: 150)) {
    VStack(spacing: 0) {
        EntryRow(
            startEnd: "08:00 - 09:00",
            projectColor: .red,
            taskName: "Design",
            clientName: "Client",
            projectName: "Project",
            duration: 3600,
            onTap: {}
        )

        Divider()
            .padding(.leading, 116)

        EntryRow(
            startEnd: "09:15",
            projectColor: .blue,
            taskName: "Prototyp testen",
            clientName: "Acme Corp",
            projectName: "Website Redesign",
            duration: 5400,
            onTap: {}
        )
    }
    .padding(.horizontal)
    .padding(.vertical, 8)
    .background(TTColors.surface)
}
