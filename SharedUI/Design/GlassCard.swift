import SwiftUI

enum GlassIntensity {
    case low, mid, high

    var material: Material {
        switch self {
        case .low: return .ultraThinMaterial
        case .mid: return .regularMaterial
        case .high: return .thickMaterial
        }
    }
}

struct GlassCardModifier: ViewModifier {
    let intensity: GlassIntensity
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(intensity.material, in: shape)
            .overlay(
                shape.strokeBorder(TTColors.text4, lineWidth: 0.5)
            )
    }
}

extension View {
    func ttGlass(
        intensity: GlassIntensity = .mid,
        cornerRadius: CGFloat = TTRadius.lg
    ) -> some View {
        modifier(GlassCardModifier(intensity: intensity, cornerRadius: cornerRadius))
    }

    func ttSurface(cornerRadius: CGFloat = TTRadius.lg) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background(TTColors.surface, in: shape)
            .overlay(shape.strokeBorder(TTColors.text4, lineWidth: 0.5))
    }
}
