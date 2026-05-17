import Foundation

enum AnalyticsTopProjectsDisplayMode: String, CaseIterable, Identifiable {
    case bar
    case pie

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bar:
            return "Balken"
        case .pie:
            return "Kreis"
        }
    }

    var systemImage: String {
        switch self {
        case .bar:
            return "chart.bar.fill"
        case .pie:
            return "chart.pie.fill"
        }
    }

    func presentation<Item>(for items: [Item]) -> AnalyticsTopProjectsPresentation<Item> {
        guard items.isEmpty == false else {
            return .empty
        }

        switch self {
        case .bar:
            return .bars(items)
        case .pie:
            return .pie(items)
        }
    }
}

enum AnalyticsTopProjectsPresentation<Item> {
    case empty
    case bars([Item])
    case pie([Item])
}

extension AnalyticsTopProjectsPresentation: Equatable where Item: Equatable {}
