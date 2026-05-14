import SwiftUI

struct SyncBanner: View {
    let lastSyncedAt: Date?

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(TTColors.green.opacity(0.16))
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(TTColors.green)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text("Sync aktuell")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(TTColors.text)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(TTColors.text2)
            }

            Spacer()

            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 16))
                .foregroundStyle(TTColors.text2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .ttSurface(cornerRadius: TTRadius.md)
    }

    private var subtitle: String {
        guard let lastSyncedAt else { return "Lokal" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.unitsStyle = .short
        return "Zuletzt: " + formatter.localizedString(for: lastSyncedAt, relativeTo: .now)
    }
}

#Preview {
    SyncBanner(lastSyncedAt: Date().addingTimeInterval(-3600))
        .padding()
}
