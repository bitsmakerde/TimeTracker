import Foundation
import SwiftData
import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

enum ProjectBudgetUnit: String, CaseIterable, Identifiable {
    case hours
    case amount

    var id: String { rawValue }
}

@Model
final class ClientProject {
    @Attribute(.unique) var id: UUID
    var clientName: String
    var name: String
    var notes: String
    var hourlyRate: Double?
    var budgetUnitRaw: String?
    var budgetTarget: Double?
    var archivedAt: Date?
    var createdAt: Date
    var accentRed: Double?
    var accentGreen: Double?
    var accentBlue: Double?

    @Relationship(deleteRule: .cascade, inverse: \WorkSession.project)
    var sessions: [WorkSession]

    @Relationship(deleteRule: .cascade, inverse: \ProjectTask.project)
    var tasks: [ProjectTask]

    init(
        clientName: String,
        name: String,
        notes: String = "",
        hourlyRate: Double? = nil,
        budgetUnitRaw: String? = nil,
        budgetTarget: Double? = nil,
        archivedAt: Date? = nil,
        accentRed: Double? = nil,
        accentGreen: Double? = nil,
        accentBlue: Double? = nil,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.clientName = clientName
        self.name = name
        self.notes = notes
        self.hourlyRate = hourlyRate
        self.budgetUnitRaw = budgetUnitRaw
        self.budgetTarget = budgetTarget
        self.archivedAt = archivedAt
        self.accentRed = accentRed
        self.accentGreen = accentGreen
        self.accentBlue = accentBlue
        self.createdAt = createdAt
        self.sessions = []
        self.tasks = []
    }
}

extension ClientProject {
    static let primaryActionColor = Color(.sRGB, red: 0.13, green: 0.44, blue: 0.86, opacity: 1)
    static let stopActionColor = Color(.sRGB, red: 0.72, green: 0.25, blue: 0.17, opacity: 1)

    var displayClientName: String {
        let trimmed = clientName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Ohne Kunde" : trimmed
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Unbenanntes Projekt" : trimmed
    }

    var sortedSessions: [WorkSession] {
        sessions.sorted { $0.startedAt > $1.startedAt }
    }

    var sortedTasks: [ProjectTask] {
        tasks.sorted { lhs, rhs in
            let titleComparison = lhs.displayTitle.localizedCaseInsensitiveCompare(rhs.displayTitle)

            if titleComparison == .orderedSame {
                return lhs.createdAt < rhs.createdAt
            }

            return titleComparison == .orderedAscending
        }
    }

    var isArchived: Bool {
        archivedAt != nil
    }

    var hasHourlyRate: Bool {
        hourlyRate != nil
    }

    var effectiveHourlyRate: Double {
        max(hourlyRate ?? 0, 0)
    }

    var budgetUnit: ProjectBudgetUnit? {
        get {
            guard let budgetUnitRaw else {
                return nil
            }

            return ProjectBudgetUnit(rawValue: budgetUnitRaw)
        }
        set { budgetUnitRaw = newValue?.rawValue }
    }

    var effectiveBudgetTarget: Double? {
        guard let budgetTarget,
              budgetTarget > 0 else {
            return nil
        }

        return budgetTarget
    }

    var hasBudget: Bool {
        budgetUnit != nil && effectiveBudgetTarget != nil
    }

    var canTrackBudgetProgress: Bool {
        guard let budgetUnit else {
            return false
        }

        if budgetUnit == .amount {
            return hasHourlyRate
        }

        return effectiveBudgetTarget != nil
    }

    var hasCustomAccentColor: Bool {
        accentRed != nil && accentGreen != nil && accentBlue != nil
    }

    var projectAccentColor: Color {
        if let customAccentColor {
            return customAccentColor
        }

        let palette = Self.projectAccentPalette
        let paletteIndex = id.uuidString.unicodeScalars.reduce(into: 0) { partialResult, scalar in
            partialResult = (partialResult * 33 + Int(scalar.value)) % palette.count
        }

        return palette[paletteIndex]
    }

    var projectActionColor: Color {
        Self.prominentActionColor(from: projectAccentColor)
    }

    func setCustomAccentColor(_ color: Color) {
        guard let components = Self.srgbComponents(from: color) else {
            return
        }

        accentRed = components.red
        accentGreen = components.green
        accentBlue = components.blue
    }

    func clearCustomAccentColor() {
        accentRed = nil
        accentGreen = nil
        accentBlue = nil
    }

    func billedAmount(for duration: TimeInterval) -> Double? {
        guard let hourlyRate else {
            return nil
        }

        return max(duration / 3600, 0) * max(hourlyRate, 0)
    }

    func setBudget(
        unit: ProjectBudgetUnit,
        target: Double?
    ) {
        guard let target,
              target > 0 else {
            clearBudget()
            return
        }

        budgetUnit = unit
        budgetTarget = target
    }

    func clearBudget() {
        budgetUnit = nil
        budgetTarget = nil
    }

    func budgetConsumedValue(for duration: TimeInterval) -> Double? {
        guard let budgetUnit else {
            return nil
        }

        return budgetValue(for: duration, in: budgetUnit)
    }

    func budgetValue(
        for duration: TimeInterval,
        in unit: ProjectBudgetUnit
    ) -> Double? {
        switch unit {
        case .hours:
            return max(duration / 3600, 0)
        case .amount:
            return billedAmount(for: duration)
        }
    }

    func budgetTargetValue(in unit: ProjectBudgetUnit) -> Double? {
        guard let storedUnit = budgetUnit,
              let target = effectiveBudgetTarget else {
            return nil
        }

        if storedUnit == unit {
            return target
        }

        return convertedBudgetValue(
            target,
            from: storedUnit,
            to: unit
        )
    }

    func convertedBudgetValue(
        _ value: Double,
        from sourceUnit: ProjectBudgetUnit,
        to targetUnit: ProjectBudgetUnit
    ) -> Double? {
        guard sourceUnit != targetUnit else {
            return value
        }

        switch (sourceUnit, targetUnit) {
        case (.hours, .hours), (.amount, .amount):
            return value
        case (.hours, .amount):
            guard let hourlyRate else {
                return nil
            }

            return max(value, 0) * max(hourlyRate, 0)
        case (.amount, .hours):
            guard let hourlyRate,
                  hourlyRate > 0 else {
                return nil
            }

            return max(value, 0) / hourlyRate
        }
    }

    func budgetRemainingValue(for duration: TimeInterval) -> Double? {
        guard let target = effectiveBudgetTarget,
              let consumed = budgetConsumedValue(for: duration) else {
            return nil
        }

        return target - consumed
    }

    func budgetProgressFraction(for duration: TimeInterval) -> Double? {
        guard let target = effectiveBudgetTarget,
              let consumed = budgetConsumedValue(for: duration),
              target > 0 else {
            return nil
        }

        return consumed / target
    }

    private static let projectAccentPalette: [Color] = [
        Color(red: 0.19, green: 0.61, blue: 0.98),
        Color(red: 0.13, green: 0.73, blue: 0.66),
        Color(red: 0.97, green: 0.66, blue: 0.16),
        Color(red: 0.91, green: 0.34, blue: 0.42),
        Color(red: 0.53, green: 0.48, blue: 0.95),
        Color(red: 0.37, green: 0.73, blue: 0.24),
        Color(red: 0.00, green: 0.73, blue: 0.80),
        Color(red: 0.88, green: 0.42, blue: 0.80),
        Color(red: 0.70, green: 0.53, blue: 0.22),
        Color(red: 0.32, green: 0.60, blue: 0.94),
    ]

    private var customAccentColor: Color? {
        guard let accentRed,
              let accentGreen,
              let accentBlue else {
            return nil
        }

        return Color(
            .sRGB,
            red: min(max(accentRed, 0), 1),
            green: min(max(accentGreen, 0), 1),
            blue: min(max(accentBlue, 0), 1),
            opacity: 1
        )
    }

    private static func srgbComponents(from color: Color) -> (red: Double, green: Double, blue: Double)? {
#if canImport(AppKit)
        guard let srgbColor = NSColor(color).usingColorSpace(.sRGB) else {
            return nil
        }

        return (
            red: Double(srgbColor.redComponent),
            green: Double(srgbColor.greenComponent),
            blue: Double(srgbColor.blueComponent)
        )
#elseif canImport(UIKit)
        let platformColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard platformColor.getRed(
            &red,
            green: &green,
            blue: &blue,
            alpha: &alpha
        ) else {
            return nil
        }

        return (
            red: Double(red),
            green: Double(green),
            blue: Double(blue)
        )
#else
        return nil
#endif
    }

    private static func prominentActionColor(from color: Color) -> Color {
        guard let components = srgbComponents(from: color) else {
            return primaryActionColor
        }

        var red = clamp(components.red)
        var green = clamp(components.green)
        var blue = clamp(components.blue)

        let luminance = relativeLuminance(red: red, green: green, blue: blue)

        if luminance > 0.48 {
            let darkenFactor = 0.48 / luminance
            red *= darkenFactor
            green *= darkenFactor
            blue *= darkenFactor
        }

        return Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }

    private static func relativeLuminance(red: Double, green: Double, blue: Double) -> Double {
        (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
