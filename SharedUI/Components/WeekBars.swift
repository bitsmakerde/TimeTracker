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
        let barWidth: CGFloat = bars.count > 24 ? 22 : bars.count > 14 ? 26 : 34

        ScrollView(.horizontal) {
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(bars.enumerated(), id: \.element.id) { index, bar in
                    VStack(spacing: 6) {
                        GeometryReader { geo in
                            let height = geo.size.height
                            let scale = height / maxValue

                            VStack(spacing: 1) {
                                ForEach(bar.parts) { part in
                                    Rectangle()
                                        .fill(part.color)
                                        .frame(height: max(part.minutes * scale, part.minutes > 0 ? 2 : 0))
                                }
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, alignment: .bottom)
                            .frame(height: height, alignment: .bottom)
                            .clipShape(.rect(cornerRadius: 6))
                            .background(TTColors.fill3, in: .rect(cornerRadius: 6))
                            .overlay {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(bar.isToday ? TTColors.accent : .clear, lineWidth: 1.5)
                            }
                        }
                        .frame(height: 110)

                        if showsLabels(at: index, for: bar) {
                            VStack(spacing: 1) {
                                Text(bar.dayLabel)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(bar.isToday ? TTColors.accent : TTColors.text2)
                                if bar.dateLabel.isEmpty == false {
                                    Text(bar.dateLabel)
                                        .font(.ttMono)
                                        .monospacedDigit()
                                        .foregroundStyle(TTColors.text3)
                                        .font(.system(size: 10))
                                }
                            }
                        } else {
                            Color.clear
                                .frame(height: 24)
                        }
                    }
                    .frame(width: barWidth)
                }
            }
            .padding(.horizontal, 1)
        }
        .scrollIndicators(.hidden)
    }

    private func showsLabels(at index: Int, for bar: WeekBar) -> Bool {
        if bar.isToday {
            return true
        }

        let stride = if bars.count > 24 {
            5
        } else if bars.count > 14 {
            3
        } else {
            1
        }

        return index.isMultiple(of: stride)
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
