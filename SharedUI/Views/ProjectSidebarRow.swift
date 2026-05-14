import SwiftUI

struct ProjectSidebarRow: View {
    let project: ClientProject
    let isActive: Bool
    let isArchived: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(accentColor)
                    .frame(width: 8, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.displayName)
                        .font(.headline)

                    Text(project.displayClientName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isActive {
                    Image(systemName: "play.circle.fill")
                        .foregroundStyle(accentColor)
                } else if isArchived {
                    Image(systemName: "archivebox.fill")
                        .foregroundStyle(accentColor)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var accentColor: Color {
        if isArchived {
            return project.projectAccentColor.opacity(0.40)
        }

        if isActive {
            return project.projectAccentColor
        }

        return project.projectAccentColor.opacity(0.82)
    }
}
