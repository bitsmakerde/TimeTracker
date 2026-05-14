import SwiftUI

enum WorkspaceSection: String, CaseIterable, Identifiable {
    case tracking
    case analytics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tracking:
            return "Aufnehmen"
        case .analytics:
            return "Auswertung"
        }
    }

    var systemImage: String {
        switch self {
        case .tracking:
            return "record.circle"
        case .analytics:
            return "chart.bar.xaxis"
        }
    }
}
