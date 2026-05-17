import SwiftUI

enum SyncBannerPresentation {
    case automatic
    case expanded
    case compactExpandable
}

enum SyncBannerStatus: Equatable {
    case localOnly
    case waitingForCloud
    case syncing(operation: CloudKitSyncOperation)
    case upToDate(lastSyncedAt: Date?)
    case failed(message: String, at: Date)

    init(cloudSyncStatus: CloudSyncStatus) {
        switch cloudSyncStatus {
        case .localOnly:
            self = .localOnly
        case .waitingForCloud:
            self = .waitingForCloud
        case let .syncing(operation, _):
            self = .syncing(operation: operation)
        case let .upToDate(lastSyncAt):
            self = .upToDate(lastSyncedAt: lastSyncAt)
        case let .failed(message, at):
            self = .failed(message: message, at: at)
        }
    }
}

struct SyncBanner: View {
    let status: SyncBannerStatus
    let presentation: SyncBannerPresentation

    @State private var isExpanded = false

    init(
        lastSyncedAt: Date?,
        presentation: SyncBannerPresentation = .automatic
    ) {
        self.status = .upToDate(lastSyncedAt: lastSyncedAt)
        self.presentation = presentation
    }

    init(
        syncStatus: CloudSyncStatus,
        presentation: SyncBannerPresentation = .automatic
    ) {
        self.status = SyncBannerStatus(cloudSyncStatus: syncStatus)
        self.presentation = presentation
    }

    var body: some View {
        if usesCompactPresentation {
            compactExpandableBanner
        } else {
            SyncBannerExpandedCard(status: status)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text(accessibilityText))
        }
    }

    private var compactExpandableBanner: some View {
        Button(action: showExpandedStatus) {
            SyncBannerToolbarIcon(status: status)
        }
        .buttonStyle(.plain)
#if os(macOS)
        .popover(isPresented: $isExpanded, arrowEdge: .bottom) {
            SyncBannerFloatingCard(status: status)
                .padding(TTSpacing.sm)
        }
#else
        .overlay(alignment: .topTrailing) {
            if isExpanded {
                SyncBannerFloatingCard(status: status)
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
        let detail = SyncBannerText.detail(status: status)
        if detail.isEmpty {
            return "\(SyncBannerText.title(status: status)), \(SyncBannerText.subtitle(status: status))"
        }

        return "\(SyncBannerText.title(status: status)), \(SyncBannerText.subtitle(status: status)), \(detail)"
    }
}

private struct SyncBannerExpandedCard: View {
    let status: SyncBannerStatus

    var body: some View {
        HStack(spacing: 40) {
            SyncBannerStatusIcon(
                status: status,
                size: 84,
                cornerRadius: 22,
                iconFont: .largeTitle
            )

            VStack(alignment: .leading, spacing: TTSpacing.sm) {
                Text(SyncBannerText.title(status: status))
                    .font(.largeTitle)
                    .foregroundStyle(SyncBannerStyle.darkPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(SyncBannerText.subtitle(status: status))
                    .font(.title)
                    .foregroundStyle(SyncBannerStyle.darkSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                let detail = SyncBannerText.detail(status: status)
                if detail.isEmpty == false {
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(SyncBannerStyle.darkSecondaryText)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: TTSpacing.md)

            Image(systemName: status.trailingSymbol)
                .font(.largeTitle)
                .foregroundStyle(status.foregroundStyle)
        }
        .padding(.horizontal, 48)
        .padding(.vertical, 28)
        .frame(minHeight: 140)
    }
}

private struct SyncBannerToolbarIcon: View {
    let status: SyncBannerStatus

    var body: some View {
        SyncBannerStatusIcon(
            status: status,
            size: SyncBannerMetrics.toolbarIconSize,
            cornerRadius: TTRadius.sm,
            iconFont: .callout,
            style: .plain
        )
    }
}

private struct SyncBannerFloatingCard: View {
    let status: SyncBannerStatus

    var body: some View {
        HStack(spacing: TTSpacing.md) {
            VStack(alignment: .leading, spacing: TTSpacing.xs) {
                Text(SyncBannerText.title(status: status))
                    .font(.callout)
                    .bold()
                    .foregroundStyle(TTColors.text)
                    .lineLimit(1)

                Text(SyncBannerText.subtitle(status: status))
                    .font(.caption)
                    .foregroundStyle(TTColors.text2)
                    .lineLimit(1)

                let detail = SyncBannerText.detail(status: status)
                if detail.isEmpty == false {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(TTColors.text3)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: TTSpacing.sm)

            Image(systemName: status.trailingSymbol)
                .font(.body)
                .foregroundStyle(status.foregroundStyle)
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
    let status: SyncBannerStatus
    let size: CGFloat
    let cornerRadius: CGFloat
    let iconFont: Font
    let style: SyncBannerStatusIconStyle

    init(
        status: SyncBannerStatus,
        size: CGFloat,
        cornerRadius: CGFloat,
        iconFont: Font,
        style: SyncBannerStatusIconStyle = .filled
    ) {
        self.status = status
        self.size = size
        self.cornerRadius = cornerRadius
        self.iconFont = iconFont
        self.style = style
    }

    var body: some View {
        ZStack {
            if style == .filled {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(status.iconBackground)
            }

            Image(systemName: status.symbol)
                .font(iconFont)
                .bold()
                .foregroundStyle(status.foregroundStyle)
        }
        .frame(width: size * 1.5, height: size)
    }
}

private enum SyncBannerStatusIconStyle {
    case filled
    case plain
}

private enum SyncBannerMetrics {
    static let toolbarButtonSize: CGFloat = 30
    static let toolbarIconSize: CGFloat = 26
    static let compactExpandedWidth: CGFloat = 244
    static let compactOverlayYOffset: CGFloat = 36
}

enum SyncBannerText {
    static func title(status: SyncBannerStatus) -> String {
        switch status {
        case .localOnly:
            return "Nur lokal"
        case .waitingForCloud:
            return "Sync bereit"
        case .syncing:
            return "Sync läuft"
        case .upToDate:
            return "Sync aktuell"
        case .failed:
            return "Sync fehlgeschlagen"
        }
    }

    static func subtitle(
        status: SyncBannerStatus,
        now: Date = .now,
        calendar: Calendar = .current,
        locale: Locale = Locale(identifier: "de_DE")
    ) -> String {
        switch status {
        case .localOnly:
            return "Lokal"
        case .waitingForCloud:
            return "iCloud wartet"
        case let .syncing(operation):
            return operation.syncBannerText
        case let .upToDate(lastSyncedAt):
            return subtitle(
                lastSyncedAt: lastSyncedAt,
                now: now,
                calendar: calendar,
                locale: locale
            )
        case let .failed(_, at):
            return subtitle(
                lastSyncedAt: at,
                now: now,
                calendar: calendar,
                locale: locale
            )
        }
    }

    static func detail(status: SyncBannerStatus) -> String {
        switch status {
        case let .failed(message, _):
            return message
        default:
            return ""
        }
    }

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

private extension CloudKitSyncOperation {
    var syncBannerText: String {
        switch self {
        case .setup:
            return "iCloud wird vorbereitet"
        case .importData:
            return "Import läuft"
        case .export:
            return "Export läuft"
        }
    }
}

private extension SyncBannerStatus {
    var symbol: String {
        switch self {
        case .failed:
            return "exclamationmark"
        case .syncing:
            return "arrow.triangle.2.circlepath"
        default:
            return "arrow.trianglehead.2.clockwise.rotate.90"
        }
    }

    var trailingSymbol: String {
        switch self {
        case .failed:
            return "exclamationmark.triangle"
        case .localOnly:
            return "externaldrive"
        default:
            return "arrow.triangle.2.circlepath"
        }
    }

    var foregroundStyle: Color {
        switch self {
        case .failed:
            return SyncBannerStyle.errorForeground
        case .waitingForCloud:
            return SyncBannerStyle.waitingForeground
        case .syncing:
            return SyncBannerStyle.syncingForeground
        default:
            return SyncBannerStyle.iconForeground
        }
    }

    var iconBackground: Color {
        switch self {
        case .failed:
            return SyncBannerStyle.errorBackground
        case .waitingForCloud:
            return SyncBannerStyle.waitingBackground
        case .syncing:
            return SyncBannerStyle.syncingBackground
        default:
            return SyncBannerStyle.toolbarIconBackground
        }
    }
}

private enum SyncBannerStyle {
    static let darkBackground = Color(.sRGB, red: 0.015, green: 0.015, blue: 0.015, opacity: 1)
    static let darkBorder = Color(.sRGB, red: 0.26, green: 0.26, blue: 0.28, opacity: 1)
    static let darkPrimaryText = Color.white
    static let darkSecondaryText = Color(.sRGB, red: 0.34, green: 0.34, blue: 0.37, opacity: 1)
    static let iconForeground = Color(.sRGB, red: 0.0, green: 0.72, blue: 0.28, opacity: 1)
    static let toolbarIconBackground = TTColors.green.opacity(0.14)
    static let toolbarIconBorder = TTColors.green.opacity(0.18)
    static let errorForeground = Color(.sRGB, red: 1.0, green: 0.29, blue: 0.25, opacity: 1)
    static let errorBackground = Color(.sRGB, red: 0.24, green: 0.035, blue: 0.03, opacity: 1)
    static let waitingForeground = Color(.sRGB, red: 0.95, green: 0.62, blue: 0.18, opacity: 1)
    static let waitingBackground = Color(.sRGB, red: 0.28, green: 0.15, blue: 0.02, opacity: 1)
    static let syncingForeground = Color(.sRGB, red: 0.25, green: 0.58, blue: 1.0, opacity: 1)
    static let syncingBackground = Color(.sRGB, red: 0.03, green: 0.11, blue: 0.24, opacity: 1)
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

#Preview("Sync Error") {
    SyncBanner(
        syncStatus: .failed(
            message: "iCloud Konto nicht erreichbar",
            at: Date(timeIntervalSince1970: 1_779_000_000)
        )
    )
    .padding()
}
