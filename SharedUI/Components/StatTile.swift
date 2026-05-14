import SwiftUI

struct StatTile: View {
    let label: String
    let value: String
    let sub: String?

    init(_ label: String, value: String, sub: String? = nil) {
        self.label = label
        self.value = value
        self.sub = sub
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(TTColors.text2)
            Text(value)
                .font(.ttMonoTitle(22))
                .foregroundStyle(TTColors.text)
                .monospacedDigit()
            if let sub {
                Text(sub)
                    .font(.system(size: 12))
                    .foregroundStyle(TTColors.text3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .ttSurface(cornerRadius: TTRadius.md)
    }
}

#Preview {
    HStack(spacing: 12) {
        StatTile("Heute", value: "3h 45m", sub: "Letzte Woche: 12h 30m")
        StatTile("Diese Woche", value: "15h 20m", sub: "Letzte Woche: 40h 10m")
        StatTile("Diese Monat", value: "60h 10m")
    }
    .padding()
}
