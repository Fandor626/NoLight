import XCTest

final class HistoryTests: XCTestCase {
    private let now = Fixtures.kyiv(2026, 11, 9, 22, 0)

    func testWindowKeys() {
        XCTAssertEqual(AppConfig.historyDays, 14)
        XCTAssertEqual(HistoryWindow.oldestKey(today: "2026-11-09"), "2026-10-26")
        let keys = HistoryWindow.previousKeys(today: "2026-11-09")
        XCTAssertEqual(keys.count, 14)
        XCTAssertEqual(keys.first, "2026-11-08")
        XCTAssertEqual(keys.last, "2026-10-26")
    }

    func testWindowCrossesMonthAndYear() {
        XCTAssertEqual(HistoryWindow.oldestKey(today: "2027-01-05"), "2026-12-22")
    }

    func testPastDayWithoutPostIsUnknownNotUnpublished() {
        let s = Fixtures.snapshot(posts: ["2026-11-05": ["1.1": [Fixtures.r(60, 120)]]], fetchedAt: now)
        let missing = HistoryWindow.pastSchedule(snapshot: s, subgroup: Fixtures.sg11, dateKey: "2026-11-04")
        XCTAssertEqual(missing.kind, .noData)
        XCTAssertEqual(missing.state(atMinute: 600), .unknown)
        let present = HistoryWindow.pastSchedule(snapshot: s, subgroup: Fixtures.sg11, dateKey: "2026-11-05")
        XCTAssertEqual(present.kind, .published)
        XCTAssertEqual(present.state(atMinute: 90), .outage)
        XCTAssertEqual(HistoryWindow.pastSchedule(snapshot: nil, subgroup: Fixtures.sg11, dateKey: "2026-11-05").kind, .noData)
    }

    func testRefreshKeepsFourteenDaysAndDropsOlder() async throws {
        let previous = Fixtures.snapshot(posts: [
            "2026-10-25": ["1.1": [Fixtures.r(0, 60)]],   // 15 днів тому — видаляється
            "2026-10-26": ["1.1": [Fixtures.r(0, 60)]],   // 14 днів тому — лишається
            "2026-11-03": ["1.1": [Fixtures.r(0, 60)]],
        ], fetchedAt: Fixtures.kyiv(2026, 11, 9, 18, 0))
        let n = now
        let results: [URL: Result<String, ScheduleError>] = [
            AppConfig.newsListURL: .success(Fixtures.listHTML),
            Fixtures.url(Fixtures.slug10Update): .success(Fixtures.post10Nov),
            Fixtures.url(Fixtures.slug9): .success(Fixtures.post10Nov)]
        let service = ScheduleService(fetcher: MockFetcher(results: results), newsListURL: AppConfig.newsListURL, now: { n })
        let snapshot = try await service.fetchLatest(previous: previous)
        XCTAssertNil(snapshot.posts["2026-10-25"])
        XCTAssertNotNil(snapshot.posts["2026-10-26"])
        XCTAssertNotNil(snapshot.posts["2026-11-03"])
        XCTAssertNotNil(snapshot.posts["2026-11-09"])
    }

    func testShortDayString() {
        XCTAssertTrue(KyivTime.shortDayString(dateKey: "2026-11-09").hasPrefix("09.11"))
    }
}
