import SwiftUI

struct SectionCard<Trailing: View, Content: View>: View {
    let title: String
    let trailing: Trailing
    let content: Content

    init(
        _ title: String,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.trailing = trailing()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(TTColors.text)
                Spacer(minLength: 8)
                trailing
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ttSurface(cornerRadius: TTRadius.lg)
    }
}

#Preview {
    SectionCard("Aktive Zeiterfassung") {
        Text("Keine aktive Zeiterfassung")
            .foregroundStyle(.secondary)
    }
}
