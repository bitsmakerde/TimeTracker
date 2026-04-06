import Foundation

enum TimeFormatting {
    private static let currencyLocale = Locale(identifier: "de_DE")

    static func digitalDuration(_ interval: TimeInterval) -> String {
        let totalSeconds = max(Int(interval.rounded(.down)), 0)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        let hourText = hours.formatted(
            .number
                .grouping(.never)
                .precision(.integerLength(2...))
        )
        let minuteText = minutes.formatted(
            .number
                .grouping(.never)
                .precision(.integerLength(2))
        )
        let secondText = seconds.formatted(
            .number
                .grouping(.never)
                .precision(.integerLength(2))
        )

        return "\(hourText):\(minuteText):\(secondText)"
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

        let minuteText = minutes.formatted(
            .number
                .grouping(.never)
                .precision(.integerLength(2))
        )

        return "\(hours):\(minuteText)"
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

        let normalized = normalizedDecimalInput(trimmed)
        let fallbackStrategy = FloatingPointFormatStyle<Double>
            .number
            .locale(Locale(identifier: "en_US_POSIX"))
            .parseStrategy

        return try? fallbackStrategy.parse(normalized)
    }

    private static func normalizedDecimalInput(_ input: String) -> String {
        let decimalSeparatorIndex = detectedDecimalSeparatorIndex(in: input)
        var normalized = ""

        for (index, character) in input.enumerated() {
            if character.isWholeNumber {
                normalized.append(character)
                continue
            }

            if (character == "-" || character == "+") && normalized.isEmpty {
                normalized.append(character)
                continue
            }

            guard (character == "," || character == "."),
                  decimalSeparatorIndex == index else {
                continue
            }

            normalized.append(".")
        }

        return normalized
    }

    private static func detectedDecimalSeparatorIndex(in input: String) -> Int? {
        let separatorIndices = input.enumerated().compactMap { index, character -> Int? in
            if character == "," || character == "." {
                return index
            }

            return nil
        }

        guard let lastSeparatorIndex = separatorIndices.last else {
            return nil
        }

        let commas = input.filter { $0 == "," }.count
        let dots = input.filter { $0 == "." }.count
        let digitsAfterLastSeparator = input.distance(
            from: input.index(input.startIndex, offsetBy: lastSeparatorIndex + 1),
            to: input.endIndex
        )

        if commas > 0 && dots > 0 {
            return lastSeparatorIndex
        }

        if commas + dots > 1 {
            return digitsAfterLastSeparator <= 2 ? lastSeparatorIndex : nil
        }

        return digitsAfterLastSeparator <= 2 ? lastSeparatorIndex : nil
    }
}
