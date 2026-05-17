import SwiftUI

enum SyncBannerPresentation {
    case automatic
    case expanded
    case compactExpandable
}

struct SyncBanner: View {
    let lastSyncedAt: Date?
    let presentation: SyncBannerPresentation

    @State private var isExpanded = false

    init(
        lastSyncedAt: Date?,
        presentation: SyncBannerPresentation = .automatic
    ) {
        self.lastSyncedAt = lastSyncedAt
        self.presentation = presentation
    }

    var body: some View {
        if usesCompactPresentation {
            compactExpandableBanner
        } else {
            SyncBannerExpandedCard(lastSyncedAt: lastSyncedAt)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text(accessibilityText))
        }
    }

    private var compactExpandableBanner: some View {
        Button(action: showExpandedStatus) {
            SyncBannerToolbarIcon()
        }
        .buttonStyle(.plain)
        .frame(
            width: SyncBannerMetrics.toolbarButtonSize,
            height: SyncBannerMetrics.toolbarButtonSize
        )
#if os(macOS)
        .popover(isPresented: $isExpanded, arrowEdge: .bottom) {
            SyncBannerFloatingCard(lastSyncedAt: lastSyncedAt)
                .padding(TTSpacing.sm)
        }
#else
        .overlay(alignment: .topTrailing) {
            if isExpanded {
                SyncBannerFloatingCard(lastSyncedAt: lastSyncedAt)
                    .frame(
                        width: SyncBannerMetrics.compactExpandedWidth,
                        alignment: .trailing
                    )
                    .offset(y: SyncBannerMetrics.compactOverlayYOffset)
                    .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .topTrailing)))
                    .zIndex(1)
            }
        }
#endif
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: isExpanded)
        .task(id: isExpanded) {
            guard isExpanded else { return }
            try? await Task.sleep(for: .seconds(2.8))
            guard Task.isCancelled == false else { return }

            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                isExpanded = false
            }
        }
        .accessibilityLabel(Text(accessibilityText))
    }

    private var usesCompactPresentation: Bool {
        switch presentation {
        case .automatic:
#if os(iOS)
            return true
#else
            return false
#endif
        case .expanded:
            return false
        case .compactExpandable:
            return true
        }
    }

    private func showExpandedStatus() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            isExpanded = true
        }
    }

    private var accessibilityText: String {
        "Sync aktuell, \(SyncBannerText.subtitle(lastSyncedAt: lastSyncedAt))"
    }
}

private struct SyncBannerExpandedCard: View {
    let lastSyncedAt: Date?

    var body: some View {
        HStack(spacing: 40) {
            SyncBannerStatusIcon(
                size: 84,
                cornerRadius: 22,
                iconFont: .largeTitle,
                background: SyncBannerStyle.darkIconBackground
            )

            VStack(alignment: .leading, spacing: TTSpacing.sm) {
                Text("Sync aktuell")
                    .font(.largeTitle)
                    .foregroundStyle(SyncBannerStyle.darkPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(SyncBannerText.subtitle(lastSyncedAt: lastSyncedAt))
                    .font(.title)
                    .foregroundStyle(SyncBannerStyle.darkSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: TTSpacing.md)

            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.largeTitle)
                .foregroundStyle(SyncBannerStyle.darkSecondaryText)
        }
        .padding(.horizontal, 48)
        .padding(.vertical, 28)
        .frame(minHeight: 140)
        .background(SyncBannerStyle.darkBackground, in: .rect(cornerRadius: 40, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .strokeBorder(SyncBannerStyle.darkBorder, lineWidth: 2)
        }
    }
}

private struct SyncBannerToolbarIcon: View {
    var body: some View {
        SyncBannerStatusIcon(
            size: SyncBannerMetrics.toolbarIconSize,
            cornerRadius: TTRadius.sm,
            iconFont: .callout,
            background: SyncBannerStyle.toolbarIconBackground
        )
        .overlay {
            RoundedRectangle(cornerRadius: TTRadius.sm, style: .continuous)
                .strokeBorder(SyncBannerStyle.toolbarIconBorder, lineWidth: 0.5)
        }
    }
}

private struct SyncBannerFloatingCard: View {
    let lastSyncedAt: Date?

    var body: some View {
        HStack(spacing: TTSpacing.md) {
            SyncBannerStatusIcon(
                size: 32,
                cornerRadius: TTRadius.sm,
                iconFont: .headline,
                background: SyncBannerStyle.toolbarIconBackground
            )

            VStack(alignment: .leading, spacing: TTSpacing.xs) {
                Text("Sync aktuell")
                    .font(.callout)
                    .bold()
                    .foregroundStyle(TTColors.text)
                    .lineLimit(1)

                Text(SyncBannerText.subtitle(lastSyncedAt: lastSyncedAt))
                    .font(.caption)
                    .foregroundStyle(TTColors.text2)
                    .lineLimit(1)
            }

            Spacer(minLength: TTSpacing.sm)

            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.body)
                .foregroundStyle(TTColors.text3)
        }
        .padding(.horizontal, TTSpacing.md)
        .padding(.vertical, TTSpacing.sm)
        .frame(minHeight: 52)
        .background(.regularMaterial, in: .rect(cornerRadius: TTRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: TTRadius.lg, style: .continuous)
                .strokeBorder(TTColors.text4, lineWidth: 0.5)
        }
        .shadow(color: SyncBannerStyle.floatingShadow, radius: 18, y: 10)
    }
}

private struct SyncBannerStatusIcon: View {
    let size: CGFloat
    let cornerRadius: CGFloat
    let iconFont: Font
    let background: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(background)

            Image(systemName: "checkmark")
                .font(iconFont)
                .bold()
                .foregroundStyle(SyncBannerStyle.iconForeground)
        }
        .frame(width: size, height: size)
    }
}

private enum SyncBannerMetrics {
    static let toolbarButtonSize: CGFloat = 30
    static let toolbarIconSize: CGFloat = 26
    static let compactExpandedWidth: CGFloat = 244
    static let compactOverlayYOffset: CGFloat = 36
}

enum SyncBannerText {
    static func subtitle(
        lastSyncedAt: Date?,
        now: Date = .now,
        calendar: Calendar = .current,
        locale: Locale = Locale(identifier: "de_DE")
    ) -> String {
        guard let lastSyncedAt else { return "Lokal" }

        let baseStyle = Date.FormatStyle(
            locale: locale,
            calendar: calendar,
            timeZone: calendar.timeZone
        )
        let dayText = if calendar.isDate(lastSyncedAt, inSameDayAs: now) {
            "Heute"
        } else {
            lastSyncedAt.formatted(baseStyle.day().month(.abbreviated))
        }
        let timeText = lastSyncedAt.formatted(baseStyle.hour().minute())

        return "\(dayText) · \(timeText)"
    }
}

private enum SyncBannerStyle {
    static let darkBackground = Color(.sRGB, red: 0.015, green: 0.015, blue: 0.015, opacity: 1)
    static let darkBorder = Color(.sRGB, red: 0.26, green: 0.26, blue: 0.28, opacity: 1)
    static let darkIconBackground = Color(.sRGB, red: 0.0, green: 0.12, blue: 0.055, opacity: 1)
    static let darkPrimaryText = Color.white
    static let darkSecondaryText = Color(.sRGB, red: 0.34, green: 0.34, blue: 0.37, opacity: 1)
    static let iconForeground = Color(.sRGB, red: 0.0, green: 0.72, blue: 0.28, opacity: 1)
    static let toolbarIconBackground = TTColors.green.opacity(0.14)
    static let toolbarIconBorder = TTColors.green.opacity(0.18)
    static let floatingShadow = Color.black.opacity(0.16)
}

#Preview("macOS") {
    SyncBanner(lastSyncedAt: Date(timeIntervalSince1970: 1_779_000_000))
        .padding()
}

#Preview("Compact") {
    SyncBanner(
        lastSyncedAt: Date(timeIntervalSince1970: 1_779_000_000),
        presentation: .compactExpandable
    )
    .padding()
}
