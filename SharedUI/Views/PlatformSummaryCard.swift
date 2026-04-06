import SwiftUI

struct PlatformSummaryCard: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .imageScale(.large)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .bold()

                Text(subtitle)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding()
        .background(.thinMaterial, in: .rect(cornerRadius: 16))
    }
}
