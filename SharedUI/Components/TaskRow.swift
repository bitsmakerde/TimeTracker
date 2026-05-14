import SwiftUI

struct TaskRow: View {
    let title: String
    let projectColor: Color
    let entryCount: Int
    let totalDuration: TimeInterval
    let hourlyRate: Double?
    let budgetProgress: Double?
    let isRunning: Bool
    let onPlayPause: () -> Void
    let onAddEntry: () -> Void
    let onEdit: () -> Void
    let onShowEntries: () -> Void

    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.18)) { expanded.toggle() }
            } label: {
                rowContent
            }
            .buttonStyle(.plain)

            if expanded {
                expandedContent
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: TTRadius.md, style: .continuous)
                .fill(TTColors.fill4)
        )
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            if isRunning {
                PulseDot(color: projectColor, size: 9)
            } else {
                Circle()
                    .strokeBorder(projectColor, lineWidth: 1.5)
                    .frame(width: 10, height: 10)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(TTColors.text)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(TTColors.text2)
            }
            Spacer(minLength: 8)
            Text(TimeFormatting.compactDuration(totalDuration))
                .font(.ttMono)
                .monospacedDigit()
                .foregroundStyle(TTColors.text)

            Button(action: onPlayPause) {
                Image(systemName: isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(projectColor))
            }
            .buttonStyle(.plain)
        }
    }

    private var subtitle: String {
        let count = "\(entryCount) Eintrag\(entryCount == 1 ? "" : (entryCount == 0 ? "e" : "e"))"
        if let hourlyRate {
            return "\(count) · \(Int(hourlyRate)) €/h"
        }
        return count
    }

    @ViewBuilder
    private var expandedContent: some View {
        VStack(spacing: 12) {
            if let budgetProgress {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Budget")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(TTColors.text2)
                        Spacer()
                        Text("\(Int(min(max(budgetProgress, 0), 1.5) * 100))%")
                            .font(.system(size: 12))
                            .foregroundStyle(TTColors.text2)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(TTColors.fill3)
                            Capsule()
                                .fill(budgetProgress > 1 ? TTColors.red : projectColor)
                                .frame(width: geo.size.width * min(max(budgetProgress, 0), 1))
                        }
                    }
                    .frame(height: 6)
                }
            }

            HStack(spacing: 8) {
                PillButton("Eintrag", systemImage: "plus", variant: .tinted, size: .sm, tint: projectColor, action: onAddEntry)
                PillButton("Bearbeiten", systemImage: "pencil", variant: .default, size: .sm, action: onEdit)
                PillButton("Einträge", systemImage: "list.bullet", variant: .default, size: .sm, action: onShowEntries)
            }
        }
    }
}

#Preview("Task row", traits: .fixedLayout(width: 390, height: 210)) {
    VStack(spacing: 12) {
        TaskRow(
            title: "Design Meeting",
            projectColor: .blue,
            entryCount: 3,
            totalDuration: 5400,
            hourlyRate: 85,
            budgetProgress: 0.75,
            isRunning: true,
            onPlayPause: {},
            onAddEntry: {},
            onEdit: {},
            onShowEntries: {}
        )

        TaskRow(
            title: "Konzept ausarbeiten",
            projectColor: .orange,
            entryCount: 0,
            totalDuration: 0,
            hourlyRate: nil,
            budgetProgress: nil,
            isRunning: false,
            onPlayPause: {},
            onAddEntry: {},
            onEdit: {},
            onShowEntries: {}
        )
    }
    .padding()
    .background(TTColors.bg)
}
