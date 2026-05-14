import SwiftUI

struct WorkspaceTabBarView: View {
    let selectedSection: WorkspaceSection
    let onSelectSection: (WorkspaceSection) -> Void

    var body: some View {
        HStack {
            Spacer(minLength: 0)

            HStack(spacing: 8) {
                ForEach(WorkspaceSection.allCases) { section in
                    WorkspaceTabButton(
                        title: section.title,
                        systemImage: section.systemImage,
                        isSelected: selectedSection == section
                    ) {
                        onSelectSection(section)
                    }
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .clipShape(.rect(cornerRadius: 16, style: .continuous))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}

#Preview("Workspace tab bar", traits: .fixedLayout(width: 520, height: 96)) {
    WorkspaceTabBarView(selectedSection: .tracking) { _ in }
        .background(TTColors.bg)
}

#Preview("Workspace tab bar dark", traits: .fixedLayout(width: 520, height: 96)) {
    WorkspaceTabBarView(selectedSection: .analytics) { _ in }
        .background(TTColors.bg)
        .preferredColorScheme(.dark)
}
