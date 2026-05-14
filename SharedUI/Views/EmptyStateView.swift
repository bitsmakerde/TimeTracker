import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

struct EmptyStateView: View {
    let onAddProject: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    .platformWindowBackground,
                    Color.teal.opacity(0.06),
                    Color.orange.opacity(0.05),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                Text("Zeiten pro Kundenprojekt erfassen")
                    .font(.largeTitle)
                    .bold()
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Lege dein erstes Projekt an und starte die Zeiterfassung direkt aus der Uebersicht.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Projekt anlegen", action: onAddProject)
                    .buttonStyle(.borderedProminent)
                    .tint(ClientProject.primaryActionColor)
            }
            .frame(maxWidth: 460, alignment: .leading)
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.background.opacity(0.88))
                    .shadow(color: .black.opacity(0.06), radius: 20, x: 0, y: 12)
            )
        }
    }
}

private extension Color {
    static var platformWindowBackground: Color {
#if canImport(AppKit)
        return Color(nsColor: .windowBackgroundColor)
#elseif canImport(UIKit)
        return Color(uiColor: .systemGroupedBackground)
#else
        return .background
#endif
    }
}

#Preview {
    EmptyStateView(onAddProject: { })
}
