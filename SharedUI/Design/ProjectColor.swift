import SwiftUI

extension ClientProject {
    /// Tinted variant of the project accent (low alpha) for wash backgrounds.
    func accentTint(_ opacity: Double = 0.14) -> Color {
        projectAccentColor.opacity(opacity)
    }

    /// Initial used in the client crumb badge.
    var clientInitial: String {
        let trimmed = displayClientName.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first else { return "?" }
        return String(first).uppercased()
    }
}
