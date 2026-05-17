import Foundation
import Testing
@testable import TimeTracker

@Suite("Sync Banner")
struct SyncBannerTests {
    @Test("Sync subtitle uses today and shortened time for same-day sync")
    func subtitleUsesTodayForSameDaySync() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let syncedAt = try #require(calendar.date(from: DateComponents(timeZone: calendar.timeZone, year: 2026, month: 5, day: 16, hour: 10, minute: 58)))
        let now = try #require(calendar.date(from: DateComponents(timeZone: calendar.timeZone, year: 2026, month: 5, day: 16, hour: 12)))

        let subtitle = SyncBannerText.subtitle(
            lastSyncedAt: syncedAt,
            now: now,
            calendar: calendar,
            locale: Locale(identifier: "de_DE")
        )

        #expect(subtitle == "Heute · 10:58")
    }

    @Test("Sync subtitle falls back to local status without sync date")
    func subtitleUsesLocalFallbackWithoutSyncDate() {
        let subtitle = SyncBannerText.subtitle(
            lastSyncedAt: nil,
            now: Date(timeIntervalSince1970: 0),
            calendar: Calendar(identifier: .gregorian),
            locale: Locale(identifier: "de_DE")
        )

        #expect(subtitle == "Lokal")
    }
}
