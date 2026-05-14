import SwiftUI

struct WorkspaceTabButton: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(minWidth: horizontalSizeClass == .compact ? nil : 160)
                .frame(maxWidth: horizontalSizeClass == .compact ? .infinity : nil)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .foregroundStyle(labelStyle)
        .background(backgroundStyle)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(strokeStyle, lineWidth: 1)
        )
        .clipShape(.rect(cornerRadius: 12, style: .continuous))
    }

    private var labelStyle: Color {
        if isSelected {
            return colorScheme == .dark ? Color.white.opacity(0.95) : Color.black.opacity(0.88)
        }

        return colorScheme == .dark ? Color.white.opacity(0.72) : Color.black.opacity(0.66)
    }

    private var backgroundStyle: Color {
        if isSelected {
            return colorScheme == .dark
                ? Color.teal.opacity(0.22)
                : Color.teal.opacity(0.14)
        }

        return colorScheme == .dark
            ? Color.white.opacity(0.04)
            : Color.white.opacity(0.86)
    }

    private var strokeStyle: Color {
        if isSelected {
            return Color.teal.opacity(0.65)
        }

        return colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.08)
    }
}

#Preview {
    VStack(spacing: 12) {
        WorkspaceTabButton(title: "Dashboard", systemImage: "house", isSelected: true, action: {})
        WorkspaceTabButton(title: "Projekte", systemImage: "folder", isSelected: false, action: {})
        WorkspaceTabButton(title: "Berichte", systemImage: "chart.bar.xaxis", isSelected: false, action: {})
    }
    .padding()
}
