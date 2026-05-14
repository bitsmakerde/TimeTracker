import SwiftUI

struct WeekBar: Identifiable {
    let id = UUID()
    let dayLabel: String
    let dateLabel: String
    let totalMinutes: Double
    let isToday: Bool
    let parts: [Part]

    struct Part: Identifiable {
        let id = UUID()
        let minutes: Double
        let color: Color
    }
}

struct WeekBars: View {
    let bars: [WeekBar]

    var body: some View {
        let maxValue = max(bars.map(\.totalMinutes).max() ?? 1, 1)
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(bars) { bar in
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        let h = geo.size.height
                        let scale = h / maxValue
                        VStack(spacing: 1) {
                            ForEach(bar.parts) { part in
                                Rectangle()
                                    .fill(part.color)
                                    .frame(height: max(part.minutes * scale, part.minutes > 0 ? 2 : 0))
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .bottom)
                        .frame(height: h, alignment: .bottom)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(TTColors.fill3)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(bar.isToday ? TTColors.accent : .clear, lineWidth: 1.5)
                        )
                    }
                    .frame(height: 110)

                    VStack(spacing: 1) {
                        Text(bar.dayLabel)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(bar.isToday ? TTColors.accent : TTColors.text2)
                        Text(bar.dateLabel)
                            .font(.ttMono)
                            .monospacedDigit()
                            .foregroundStyle(TTColors.text3)
                            .font(.system(size: 10))
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

#Preview("Week bar", traits: .fixedLayout(width: 120, height: 170)) {
    let weekBar = WeekBar(
        dayLabel: "Mo",
        dateLabel: "11",
        totalMinutes: 120,
        isToday: true,
        parts: [
            .init(minutes: 45, color: .red),
            .init(minutes: 30, color: .blue),
            .init(minutes: 45, color: .green),
        ]
    )

    WeekBars(bars: [weekBar])
        .padding()
        .background(TTColors.surface)
}
