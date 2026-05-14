import SwiftUI

struct TimerHero: View {
    let clientName: String
    let projectName: String
    let taskName: String?
    let projectColor: Color
    let elapsed: TimeInterval
    let hourlyRate: Double?
    let billed: Double?
    let budgetProgress: Double?
    let runningSinceLabel: String?
    let compact: Bool
    let onPause: (() -> Void)?
    let onStop: (() -> Void)?

    @Environment(\.projectColorVariant) private var variant

    var body: some View {
        ZStack(alignment: .topLeading) {
            background

            VStack(alignment: .leading, spacing: 14) {
                topRow
                projectLine
                timeRow
                if let budgetProgress {
                    budgetBar(progress: budgetProgress)
                }
                actionRow
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: TTRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TTRadius.xl, style: .continuous)
                .strokeBorder(TTColors.text4, lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var background: some View {
        RoundedRectangle(cornerRadius: TTRadius.xl, style: .continuous)
            .fill(TTColors.surface)

        switch variant {
        case .tinted:
            RoundedRectangle(cornerRadius: TTRadius.xl, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [projectColor.opacity(0.22), projectColor.opacity(0)],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 320
                    )
                )
                .allowsHitTesting(false)
        case .chromed:
            VStack {
                Rectangle()
                    .fill(projectColor)
                    .frame(height: 4)
                Spacer(minLength: 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: TTRadius.xl, style: .continuous))
            .allowsHitTesting(false)
        }
    }

    private var topRow: some View {
        HStack(alignment: .center) {
            HStack(spacing: 8) {
                PulseDot(color: TTColors.live, size: 8)
                Text(statusText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TTColors.text2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(TTColors.fill3)
            )

            Spacer()

            HStack(spacing: 8) {
                Text(clientName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(TTColors.text2)
                ClientBadge(initial: String(clientName.prefix(1)).uppercased(), color: projectColor)
            }
        }
    }

    private var projectLine: some View {
        HStack(spacing: 8) {
            Circle().fill(projectColor).frame(width: 8, height: 8)
            Text(projectName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(TTColors.text)
            if let taskName {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(TTColors.text3)
                Text(taskName)
                    .font(.system(size: 15))
                    .foregroundStyle(TTColors.text2)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private var timeRow: some View {
        HStack(alignment: .lastTextBaseline) {
            Text(TimeFormatting.digitalDuration(elapsed))
                .font(.ttMonoTitle(compact ? 32 : 44))
                .monospacedDigit()
                .foregroundStyle(TTColors.text)
            Spacer()
            if let hourlyRate {
                VStack(alignment: .trailing, spacing: 2) {
                    if let billed {
                        Text(TimeFormatting.euroAmount(billed))
                            .font(.ttMonoTitle(15))
                            .foregroundStyle(projectColor)
                    }
                    Text("\(Int(hourlyRate)) €/h")
                        .font(.system(size: 12))
                        .foregroundStyle(TTColors.text3)
                }
            }
        }
    }

    @ViewBuilder
    private func budgetBar(progress: Double) -> some View {
        let clamped = min(max(progress, 0), 1.5)
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Budget")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TTColors.text2)
                Spacer()
                Text("\(Int(clamped * 100))%")
                    .font(.ttMono)
                    .font(.system(size: 12))
                    .foregroundStyle(TTColors.text2)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(TTColors.fill3)
                    Capsule()
                        .fill(progress > 1 ? TTColors.red : projectColor)
                        .frame(width: geo.size.width * min(clamped, 1))
                }
            }
            .frame(height: 6)
        }
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            if let onPause {
                Button(action: onPause) {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(PillButtonStyle(variant: .glass, tint: projectColor))
            }
            if let onStop {
                Button(action: onStop) {
                    HStack(spacing: 8) {
                        Image(systemName: "stop.fill")
                        Text("Stop")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                }
                .buttonStyle(PillButtonStyle(variant: .primary, tint: projectColor))
            }
        }
    }

    private var statusText: String {
        if let runningSinceLabel {
            return "Aktiv · seit \(runningSinceLabel)"
        }
        return "Aktiv"
    }
}

struct ClientBadge: View {
    let initial: String
    let color: Color

    var body: some View {
        Text(initial)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(Circle().fill(color))
    }
}

#Preview {
    TimerHero(
        clientName: "Acme Corp",
        projectName: "Website Redesign",
        taskName: "Design Landing Page",
        projectColor: .blue,
        elapsed: 7265,
        hourlyRate: 85,
        billed: 1700,
        budgetProgress: 0.75,
        runningSinceLabel: "2h 1m",
        compact: false,
        onPause: {},
        onStop: {}
    )
    .padding()
}
