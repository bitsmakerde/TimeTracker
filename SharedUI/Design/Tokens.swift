import SwiftUI

enum TTRadius {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 14
    static let lg: CGFloat = 18
    static let xl: CGFloat = 22
    static let pill: CGFloat = 999
}

enum TTSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
}

enum TTColors {
    // MARK: - Backgrounds & surfaces

    /// Grouped background (System Gray 6 light / true black dark).
    static let bg = Color(
        light: Color(.sRGB, red: 242.0/255, green: 242.0/255, blue: 247.0/255, opacity: 1),
        dark: Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 1)
    )

    /// Secondary system grouped background — used as card surface.
    static let surface = Color(
        light: Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 1),
        dark: Color(.sRGB, red: 28.0/255, green: 28.0/255, blue: 30.0/255, opacity: 1)
    )

    /// Tertiary system grouped background.
    static let surface2 = Color(
        light: Color(.sRGB, red: 242.0/255, green: 242.0/255, blue: 247.0/255, opacity: 1),
        dark: Color(.sRGB, red: 44.0/255, green: 44.0/255, blue: 46.0/255, opacity: 1)
    )

    // MARK: - Fills (translucent grays)

    static let fill1 = Color(
        light: Color(.sRGB, red: 120.0/255, green: 120.0/255, blue: 128.0/255, opacity: 0.20),
        dark: Color(.sRGB, red: 120.0/255, green: 120.0/255, blue: 128.0/255, opacity: 0.36)
    )
    static let fill2 = Color(
        light: Color(.sRGB, red: 120.0/255, green: 120.0/255, blue: 128.0/255, opacity: 0.16),
        dark: Color(.sRGB, red: 120.0/255, green: 120.0/255, blue: 128.0/255, opacity: 0.32)
    )
    static let fill3 = Color(
        light: Color(.sRGB, red: 118.0/255, green: 118.0/255, blue: 128.0/255, opacity: 0.12),
        dark: Color(.sRGB, red: 118.0/255, green: 118.0/255, blue: 128.0/255, opacity: 0.24)
    )
    static let fill4 = Color(
        light: Color(.sRGB, red: 116.0/255, green: 116.0/255, blue: 128.0/255, opacity: 0.08),
        dark: Color(.sRGB, red: 118.0/255, green: 118.0/255, blue: 128.0/255, opacity: 0.18)
    )

    // MARK: - Text

    static let text = Color(
        light: Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 1),
        dark: Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 1)
    )
    static let text2 = Color(
        light: Color(.sRGB, red: 60.0/255, green: 60.0/255, blue: 67.0/255, opacity: 0.60),
        dark: Color(.sRGB, red: 235.0/255, green: 235.0/255, blue: 245.0/255, opacity: 0.60)
    )
    static let text3 = Color(
        light: Color(.sRGB, red: 60.0/255, green: 60.0/255, blue: 67.0/255, opacity: 0.30),
        dark: Color(.sRGB, red: 235.0/255, green: 235.0/255, blue: 245.0/255, opacity: 0.30)
    )
    static let text4 = Color(
        light: Color(.sRGB, red: 60.0/255, green: 60.0/255, blue: 67.0/255, opacity: 0.18),
        dark: Color(.sRGB, red: 235.0/255, green: 235.0/255, blue: 245.0/255, opacity: 0.18)
    )

    // MARK: - Separator

    static let separator = Color(
        light: Color(.sRGB, red: 60.0/255, green: 60.0/255, blue: 67.0/255, opacity: 0.29),
        dark: Color(.sRGB, red: 84.0/255, green: 84.0/255, blue: 88.0/255, opacity: 0.65)
    )

    // MARK: - Apple system colors

    static let red = Color(
        light: Color(.sRGB, red: 255.0/255, green: 59.0/255, blue: 48.0/255, opacity: 1),
        dark: Color(.sRGB, red: 255.0/255, green: 69.0/255, blue: 58.0/255, opacity: 1)
    )
    static let orange = Color(
        light: Color(.sRGB, red: 255.0/255, green: 149.0/255, blue: 0, opacity: 1),
        dark: Color(.sRGB, red: 255.0/255, green: 159.0/255, blue: 10.0/255, opacity: 1)
    )
    static let yellow = Color(
        light: Color(.sRGB, red: 255.0/255, green: 204.0/255, blue: 0, opacity: 1),
        dark: Color(.sRGB, red: 255.0/255, green: 214.0/255, blue: 10.0/255, opacity: 1)
    )
    static let green = Color(
        light: Color(.sRGB, red: 52.0/255, green: 199.0/255, blue: 89.0/255, opacity: 1),
        dark: Color(.sRGB, red: 48.0/255, green: 209.0/255, blue: 88.0/255, opacity: 1)
    )
    static let mint = Color(
        light: Color(.sRGB, red: 0, green: 199.0/255, blue: 190.0/255, opacity: 1),
        dark: Color(.sRGB, red: 99.0/255, green: 230.0/255, blue: 226.0/255, opacity: 1)
    )
    static let teal = Color(
        light: Color(.sRGB, red: 48.0/255, green: 176.0/255, blue: 199.0/255, opacity: 1),
        dark: Color(.sRGB, red: 64.0/255, green: 200.0/255, blue: 224.0/255, opacity: 1)
    )
    static let cyan = Color(
        light: Color(.sRGB, red: 50.0/255, green: 173.0/255, blue: 230.0/255, opacity: 1),
        dark: Color(.sRGB, red: 100.0/255, green: 210.0/255, blue: 1, opacity: 1)
    )
    static let blue = Color(
        light: Color(.sRGB, red: 0, green: 122.0/255, blue: 1, opacity: 1),
        dark: Color(.sRGB, red: 10.0/255, green: 132.0/255, blue: 1, opacity: 1)
    )
    static let indigo = Color(
        light: Color(.sRGB, red: 88.0/255, green: 86.0/255, blue: 214.0/255, opacity: 1),
        dark: Color(.sRGB, red: 94.0/255, green: 92.0/255, blue: 230.0/255, opacity: 1)
    )
    static let purple = Color(
        light: Color(.sRGB, red: 175.0/255, green: 82.0/255, blue: 222.0/255, opacity: 1),
        dark: Color(.sRGB, red: 191.0/255, green: 90.0/255, blue: 242.0/255, opacity: 1)
    )
    static let pink = Color(
        light: Color(.sRGB, red: 1, green: 45.0/255, blue: 85.0/255, opacity: 1),
        dark: Color(.sRGB, red: 1, green: 55.0/255, blue: 95.0/255, opacity: 1)
    )
    static let brown = Color(
        light: Color(.sRGB, red: 162.0/255, green: 132.0/255, blue: 94.0/255, opacity: 1),
        dark: Color(.sRGB, red: 172.0/255, green: 142.0/255, blue: 104.0/255, opacity: 1)
    )

    // MARK: - Semantic accents

    /// Default app accent — coral / systemRed.
    static let accent = red
    /// Live indicator (running timer dot) — systemGreen.
    static let live = green
}

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension Color {
    init(light: Color, dark: Color) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { trait in
            switch trait.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
        #elseif canImport(AppKit)
        self.init(nsColor: NSColor(name: nil) { appearance in
            let darkNames: [NSAppearance.Name] = [
                .darkAqua, .vibrantDark,
                .accessibilityHighContrastDarkAqua,
                .accessibilityHighContrastVibrantDark,
            ]
            let isDark = appearance.bestMatch(from: darkNames) != nil
            return NSColor(isDark ? dark : light)
        })
        #else
        self = light
        #endif
    }
}

extension Font {
    /// Monospaced digit body font for time / currency.
    static let ttMono = Font.system(.body, design: .monospaced)
    static func ttMonoTitle(_ size: CGFloat) -> Font {
        Font.system(size: size, weight: .semibold, design: .monospaced)
    }
}
