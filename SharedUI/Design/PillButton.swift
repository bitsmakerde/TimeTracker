import SwiftUI

enum PillVariant {
    case primary
    case tinted
    case `default`
    case glass
}

enum PillSize {
    case sm, md, lg

    var height: CGFloat {
        switch self {
        case .sm: return 28
        case .md: return 38
        case .lg: return 50
        }
    }

    var hPadding: CGFloat {
        switch self {
        case .sm: return 10
        case .md: return 14
        case .lg: return 18
        }
    }

    var font: Font {
        switch self {
        case .sm: return .system(size: 13, weight: .semibold)
        case .md: return .system(size: 15, weight: .semibold)
        case .lg: return .system(size: 17, weight: .semibold)
        }
    }
}

struct PillButton: View {
    let title: String
    let systemImage: String?
    let variant: PillVariant
    let size: PillSize
    let tint: Color?
    let action: () -> Void

    init(
        _ title: String,
        systemImage: String? = nil,
        variant: PillVariant = .default,
        size: PillSize = .md,
        tint: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.variant = variant
        self.size = size
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(size.font)
            .padding(.horizontal, size.hPadding)
            .frame(height: size.height)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PillButtonStyle(variant: variant, tint: tint))
    }
}

struct PillButtonStyle: ButtonStyle {
    let variant: PillVariant
    let tint: Color?

    func makeBody(configuration: Configuration) -> some View {
        let resolvedTint = tint ?? TTColors.accent

        let foreground: Color = {
            switch variant {
            case .primary: return .white
            case .tinted: return resolvedTint
            case .default: return TTColors.text
            case .glass: return TTColors.text
            }
        }()

        return configuration.label
            .foregroundStyle(foreground)
            .background(
                Capsule(style: .continuous)
                    .fill(backgroundFill(resolvedTint: resolvedTint))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(borderColor(resolvedTint: resolvedTint), lineWidth: 0.5)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private func backgroundFill(resolvedTint: Color) -> AnyShapeStyle {
        switch variant {
        case .primary:
            return AnyShapeStyle(resolvedTint)
        case .tinted:
            return AnyShapeStyle(resolvedTint.opacity(0.14))
        case .default:
            return AnyShapeStyle(TTColors.fill3)
        case .glass:
            return AnyShapeStyle(.regularMaterial)
        }
    }

    private func borderColor(resolvedTint: Color) -> Color {
        switch variant {
        case .primary: return resolvedTint
        case .tinted: return resolvedTint.opacity(0.18)
        case .default, .glass: return TTColors.text4
        }
    }
}

struct CircleIconButton: View {
    let systemImage: String
    let size: CGFloat
    let variant: PillVariant
    let tint: Color?
    let action: () -> Void

    init(
        systemImage: String,
        size: CGFloat = 44,
        variant: PillVariant = .default,
        tint: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.size = size
        self.variant = variant
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.42, weight: .semibold))
                .frame(width: size, height: size)
        }
        .buttonStyle(CircleIconButtonStyle(variant: variant, tint: tint))
    }
}

private struct CircleIconButtonStyle: ButtonStyle {
    let variant: PillVariant
    let tint: Color?

    func makeBody(configuration: Configuration) -> some View {
        let resolvedTint = tint ?? TTColors.accent

        let foreground: Color = {
            switch variant {
            case .primary: return .white
            case .tinted: return resolvedTint
            case .default, .glass: return TTColors.text
            }
        }()

        let fill: AnyShapeStyle = {
            switch variant {
            case .primary: return AnyShapeStyle(resolvedTint)
            case .tinted: return AnyShapeStyle(resolvedTint.opacity(0.14))
            case .default: return AnyShapeStyle(TTColors.fill3)
            case .glass: return AnyShapeStyle(.regularMaterial)
            }
        }()

        return configuration.label
            .foregroundStyle(foreground)
            .background(Circle().fill(fill))
            .overlay(
                Circle().strokeBorder(
                    variant == .primary ? resolvedTint : TTColors.text4,
                    lineWidth: 0.5
                )
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview("Pill buttons") {
    VStack(spacing: 12) {
        PillButton(
            "Timer starten",
            systemImage: "play.fill",
            variant: .primary,
            size: .lg,
            tint: ClientProject.primaryActionColor
        ) {}

        PillButton(
            "Filter",
            systemImage: "line.3.horizontal.decrease.circle",
            variant: .tinted,
            tint: .teal
        ) {}

        PillButton("Mehr anzeigen", variant: .glass) {}

        CircleIconButton(
            systemImage: "ellipsis",
            variant: .default
        ) {}
    }
    .padding()
    .frame(width: 320)
}
