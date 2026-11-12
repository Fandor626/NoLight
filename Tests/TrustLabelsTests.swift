import XCTest

final class TrustLabelsTests: XCTestCase {
    private let fetched = Fixtures.kyiv(2026, 11, 10, 12, 0)

    private func p(at now: Date) -> SubgroupPresentation {
        let s = Fixtures.snapshot(posts: ["2026-11-10": ["1.1": Fixtures.outages11],
                                          "2026-11-11": ["1.1": Fixtures.outages11]], fetchedAt: fetched)
        return SubgroupPresentation(snapshot: s, subgroup: Fixtures.sg11, now: now)
    }

    func testFreshUnderOneHour() {
        let x = p(at: fetched.addingTimeInterval(59 * 60))
        XCTAssertFalse(x.showsStaleWarning)
        XCTAssertFalse(x.showsExpiredWarning)
    }

    func testStaleAfterOneHour() {
        let x = p(at: fetched.addingTimeInterval(3600))
        XCTAssertTrue(x.showsStaleWarning)
        XCTAssertFalse(x.showsExpiredWarning)
        XCTAssertNotEqual(x.status.state, .unknown)   // застарілий графік ще показується
    }

    func testExpiredAfter24Hours() {
        let x = p(at: fetched.addingTimeInterval(24 * 3600))
        XCTAssertTrue(x.showsExpiredWarning)
        XCTAssertFalse(x.showsStaleWarning)
        XCTAssertEqual(x.status.state, .unknown)      // протерміноване не видається за актуальне
    }

    func testUpdatedAtText() {
        XCTAssertEqual(p(at: Fixtures.kyiv(2026, 11, 10, 13, 0)).updatedText, "Оновлено о 12:00")
        XCTAssertEqual(p(at: Fixtures.kyiv(2026, 11, 11, 9, 0)).updatedText, "Оновлено 10.11 12:00")
    }

    func testLabels() {
        XCTAssertEqual(FreshnessCopy.stale, "Застаріло")
        XCTAssertEqual(FreshnessCopy.expired, "Протерміновано")
        XCTAssertEqual(FreshnessCopy.unofficial, "Неофіційне джерело")
        XCTAssertTrue(PlaceSource.outageDataAPI.title.contains("неофіційне"))
    }

    /// AC4: помилка мережі для API не стирає кеш.
    func testApiNetworkErrorKeepsCache() async throws {
        let cache = FileScheduleCache(fileURL: makeTempCacheURL())
        let old = Fixtures.snapshot(posts: ["2026-11-10": ["1.1": [Fixtures.r(0, 60)]]], fetchedAt: fetched)
        try cache.save(old)
        let url = OutageDataService.url(for: .poltava)
        let service = OutageDataService(fetcher: MockFetcher(results: [url: .failure(.offline)]), region: .poltava)
        let repo = ScheduleRepository(service: service, cache: cache)
        do { _ = try await repo.refresh(); XCTFail("Очікувалась помилка") }
        catch { XCTAssertEqual(error as? ScheduleError, .offline) }
        XCTAssertEqual(cache.load(), old)
    }
}
