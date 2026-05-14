import SwiftUI

struct DayProfile: View {
    /// 24 buckets, each can have multiple stacked parts (project color → minutes)
    struct HourBucket: Identifiable {
        let id = UUID()
        let hour: Int
        let parts: [Part]

        struct Part: Identifiable {
            let id = UUID()
            let minutes: Double
            let color: Color
        }
    }

    let buckets: [HourBucket]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(buckets) { bucket in
                    GeometryReader { geo in
                        let segmentSpacing: CGFloat = 1
                        let totalMinutes = min(bucket.parts.reduce(0) { $0 + $1.minutes }, 60)
                        let filledHeight = geo.size.height * (totalMinutes / 60)
                        let visibleParts = bucket.parts.filter { $0.minutes > 0 }
                        let totalSegmentSpacing = segmentSpacing * CGFloat(max(visibleParts.count - 1, 0))
                        let availableSegmentHeight = max(filledHeight - totalSegmentSpacing, 0)

                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(TTColors.fill4)

                            VStack(spacing: segmentSpacing) {
                                ForEach(visibleParts) { part in
                                    Rectangle()
                                        .fill(part.color)
                                        .frame(height: max(availableSegmentHeight * (part.minutes / totalMinutes), part.minutes > 0 ? 2 : 0))
                                }
                            }
                            .frame(height: filledHeight, alignment: .bottom)
                        }
                        .clipShape(.rect(cornerRadius: 3))
                    }
                    .frame(height: 60)
                }
            }
            HStack {
                ForEach([0, 6, 12, 18], id: \.self) { hr in
                    Text(String(format: "%02d", hr))
                        .font(.ttMono)
                        .font(.system(size: 10))
                        .foregroundStyle(TTColors.text3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

#Preview("Day profile", traits: .fixedLayout(width: 390, height: 110)) {
    let buckets = (0..<24).map { hour in
        let parts: [DayProfile.HourBucket.Part] = switch hour {
        case 8:
            [.init(minutes: 30, color: .blue)]
        case 9:
            [.init(minutes: 45, color: .blue), .init(minutes: 15, color: .green)]
        case 10:
            [.init(minutes: 60, color: .green)]
        case 13:
            [.init(minutes: 25, color: .orange)]
        case 14:
            [.init(minutes: 40, color: .orange), .init(minutes: 20, color: .purple)]
        case 15:
            [.init(minutes: 35, color: .purple)]
        default:
            []
        }

        return DayProfile.HourBucket(hour: hour, parts: parts)
    }

    DayProfile(buckets: buckets)
        .padding()
        .background(TTColors.surface)
}
