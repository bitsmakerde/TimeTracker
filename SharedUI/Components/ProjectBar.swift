import SwiftUI

struct ProjectBar: View {
    let projectColor: Color
    let projectName: String
    let clientName: String
    let duration: TimeInterval
    let percentage: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle().fill(projectColor).frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 1) {
                    Text(projectName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(TTColors.text)
                    Text(clientName)
                        .font(.system(size: 11))
                        .foregroundStyle(TTColors.text2)
                }
                Spacer()
                Text(TimeFormatting.compactDuration(duration))
                    .font(.ttMono)
                    .monospacedDigit()
                    .foregroundStyle(TTColors.text)
                Text(String(format: "%.0f%%", percentage * 100))
                    .font(.system(size: 12))
                    .foregroundStyle(TTColors.text2)
                    .frame(width: 44, alignment: .trailing)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(TTColors.fill3)
                    Capsule()
                        .fill(projectColor)
                        .frame(width: geo.size.width * min(max(percentage, 0), 1))
                }
            }
            .frame(height: 6)
        }
    }
}

#Preview {
    ProjectBar(
        projectColor: .blue,
        projectName: "Projekt Alpha",
        clientName: "Kunde XYZ",
        duration: 3 * 3600 + 45 * 60,
        percentage: 0.75
    )
    .padding()
}
