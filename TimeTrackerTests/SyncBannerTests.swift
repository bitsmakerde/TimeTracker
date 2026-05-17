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

    @Test("Failed sync status exposes error copy")
    func failedSyncStatusExposesErrorCopy() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let failedAt = try #require(calendar.date(from: DateComponents(timeZone: calendar.timeZone, year: 2026, month: 5, day: 16, hour: 10, minute: 58)))
        let now = try #require(calendar.date(from: DateComponents(timeZone: calendar.timeZone, year: 2026, month: 5, day: 16, hour: 12)))
        let status = SyncBannerStatus(
            cloudSyncStatus: .failed(message: "iCloud Konto nicht erreichbar", at: failedAt)
        )

        #expect(SyncBannerText.title(status: status) == "Sync fehlgeschlagen")
        #expect(
            SyncBannerText.subtitle(
                status: status,
                now: now,
                calendar: calendar,
                locale: Locale(identifier: "de_DE")
            ) == "Heute · 10:58"
        )
        #expect(SyncBannerText.detail(status: status) == "iCloud Konto nicht erreichbar")
    }

    @Test("Cloud status maps to banner status")
    func cloudStatusMapsToBannerStatus() {
        let syncedAt = Date(timeIntervalSince1970: 1_779_000_000)
        let failedAt = Date(timeIntervalSince1970: 1_779_100_000)

        #expect(SyncBannerStatus(cloudSyncStatus: .upToDate(lastSyncAt: syncedAt)) == .upToDate(lastSyncedAt: syncedAt))
        #expect(SyncBannerStatus(cloudSyncStatus: .localOnly) == .localOnly)
        #expect(SyncBannerStatus(cloudSyncStatus: .waitingForCloud) == .waitingForCloud)
        #expect(SyncBannerStatus(cloudSyncStatus: .syncing(operation: .export, startedAt: syncedAt)) == .syncing(operation: .export))
        #expect(SyncBannerStatus(cloudSyncStatus: .failed(message: "Fehler", at: failedAt)) == .failed(message: "Fehler", at: failedAt))
    }
}
