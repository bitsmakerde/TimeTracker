import SwiftUI

enum ProjectColorVariant: String, CaseIterable, Identifiable {
    case tinted
    case chromed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .tinted: return "Wash"
        case .chromed: return "Bar"
        }
    }
}

private struct ProjectColorVariantKey: EnvironmentKey {
    static let defaultValue: ProjectColorVariant = .chromed
}

extension EnvironmentValues {
    var projectColorVariant: ProjectColorVariant {
        get { self[ProjectColorVariantKey.self] }
        set { self[ProjectColorVariantKey.self] = newValue }
    }
}
