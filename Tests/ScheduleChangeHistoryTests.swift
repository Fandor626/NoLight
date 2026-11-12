import XCTest

final class ScheduleChangeHistoryTests: XCTestCase {
    private let now = Fixtures.kyiv(2026, 11, 20, 12, 0)
    private let home = UUID(), work = UUID()

    private func change(_ place: UUID, daysAgo: Double, key: String = "2026-11-20") -> ScheduleChange {
        ScheduleChange(placeID: place, dateKey: key, detectedAt: now.addingTimeInterval(-daysAgo * 24 * 3600),
                       old: [Fixtures.r(0, 60)], new: [Fixtures.r(0, 120)])
    }

    func testNewestFirstAndOlderThan14DaysRemoved() {
        let merged = ScheduleChangeHistory.merged([change(home, daysAgo: 15), change(home, daysAgo: 2)],
                                                  adding: [change(home, daysAgo: 0)],
                                                  placeIDs: [home], now: now)
        XCTAssertEqual(merged.map(\.detectedAt), [now, now.addingTimeInterval(-2 * 24 * 3600)])
    }

    func testDeletedPlaceEntriesAreRemoved() {
        let merged = ScheduleChangeHistory.merged([change(work, daysAgo: 1)], adding: [change(home, daysAgo: 0)],
                                                  placeIDs: [home], now: now)
        XCTAssertEqual(merged.map(\.placeID), [home])
    }

    func testEntriesForPlace() {
        let all = [change(home, daysAgo: 0), change(work, daysAgo: 0), change(home, daysAgo: 1)]
        XCTAssertEqual(ScheduleChangeHistory.entries(for: home, in: all).count, 2)
    }

    func testStoreRoundTrip() {
        let suite = "nl-hist-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ScheduleChangeHistoryStore(defaults: defaults)
        let place = Place(name: "Дім", subgroup: Fixtures.sg11)
        let c = ScheduleChange(placeID: place.id, dateKey: "2026-11-20", detectedAt: now,
                               old: [Fixtures.r(0, 60)], new: [])
        store.record([c], places: [place], now: now)
        XCTAssertEqual(ScheduleChangeHistoryStore(defaults: defaults).changes, [c])
    }
}
