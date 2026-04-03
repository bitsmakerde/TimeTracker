import Foundation

enum TimeFormatting {
    private static let currencyLocale = Locale(identifier: "de_DE")

    static func digitalDuration(_ interval: TimeInterval) -> String {
        let totalSeconds = max(Int(interval.rounded(.down)), 0)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    static func compactDuration(_ interval: TimeInterval) -> String {
        let totalSeconds = max(Int(interval.rounded(.down)), 0)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours == 0 {
            return "\(minutes)m"
        }

        if minutes == 0 {
            return "\(hours)h"
        }

        return "\(hours)h \(minutes)m"
    }

    static func menuBarDuration(_ interval: TimeInterval) -> String {
        let totalSeconds = max(Int(interval.rounded(.down)), 0)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        return "\(hours):" + String(format: "%02d", minutes)
    }

    static func shortTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func shortDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    static func euroAmount(_ amount: Double) -> String {
        amount.formatted(
            .currency(code: "EUR")
                .locale(currencyLocale)
        )
    }

    static func decimalInput(_ amount: Double?) -> String {
        guard let amount else {
            return ""
        }

        return amount.formatted(
            .number
                .locale(currencyLocale)
                .precision(.fractionLength(0...2))
        )
    }

    static func parseDecimalInput(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return nil
        }

        let formatter = NumberFormatter()
        formatter.locale = currencyLocale
        formatter.numberStyle = .decimal

        if let number = formatter.number(from: trimmed) {
            return number.doubleValue
        }

        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }
}
