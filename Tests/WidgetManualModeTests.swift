import XCTest

/// Рахує звернення до мережі.
private final class CountingSource: ScheduleSourcing, @unchecked Sendable {
    private let lock = NSLock()
    private var _calls = 0
    let result: ScheduleSnapshot
    init(result: ScheduleSnapshot) { self.result = result }
    var calls: Int { lock.withLock { _calls } }
    func fetchLatest(previous: ScheduleSnapshot?) async throws -> ScheduleSnapshot {
        lock.withLock { _calls += 1 }
        return result
    }
}

final class WidgetManualModeTests: XCTestCase {
    private let now = Fixtures.kyiv(2026, 11, 9, 18, 0)

    private func makeRepo(cachedAt: Date) throws -> (ScheduleRepository, CountingSource, ScheduleSnapshot) {
        let cache = FileScheduleCache(fileURL: makeTempCacheURL())
        let old = Fixtures.snapshot(posts: ["2026-11-09": ["1.1": [Fixtures.r(0, 60)]]], fetchedAt: cachedAt)
        try cache.save(old)
        let fresh = Fixtures.snapshot(posts: ["2026-11-09": ["1.1": [Fixtures.r(600, 720)]]], fetchedAt: now)
        let source = CountingSource(result: fresh)
        let n = now
        return (ScheduleRepository(service: source, cache: cache, now: { n }), source, old)
    }

    func testModeFlags() {
        XCTAssertTrue(RefreshMode.automatic.allowsWidgetSelfRefresh)
        XCTAssertFalse(RefreshMode.manual.allowsWidgetSelfRefresh)
        let store = RefreshSettingsStore(defaults: UserDefaults(suiteName: "WidgetManualModeTests-\(UUID().uuidString)")!)
        XCTAssertTrue(store.allowsWidgetSelfRefresh)
        store.mode = .manual
        XCTAssertFalse(store.allowsWidgetSelfRefresh)
    }

    func testManualModeUsesCacheWithoutNetwork() async throws {
        let (repo, source, old) = try makeRepo(cachedAt: Fixtures.kyiv(2026, 11, 9, 10, 0))
        let snap = await repo.widgetSnapshot(allowsSelfRefresh: false)
        XCTAssertEqual(snap, old)
        XCTAssertEqual(source.calls, 0)
    }

    func testAutomaticModeRefreshesStaleCache() async throws {
        let (repo, source, _) = try makeRepo(cachedAt: Fixtures.kyiv(2026, 11, 9, 17, 0))
        let snap = await repo.widgetSnapshot(allowsSelfRefresh: true)
        XCTAssertEqual(snap?.fetchedAt, now)
        XCTAssertEqual(source.calls, 1)
    }

    func testAutomaticModeKeepsFreshCache() async throws {
        let (repo, source, old) = try makeRepo(cachedAt: Fixtures.kyiv(2026, 11, 9, 17, 50))
        let snap = await repo.widgetSnapshot(allowsSelfRefresh: true)
        XCTAssertEqual(snap, old)
        XCTAssertEqual(source.calls, 0)
    }

    func testExplicitRefreshWorksInManualMode() async throws {
        let (repo, source, _) = try makeRepo(cachedAt: Fixtures.kyiv(2026, 11, 9, 10, 0))
        _ = try await repo.refresh()
        XCTAssertEqual(source.calls, 1)
    }

    func testManualModeStaleCacheStillShowsWarning() async throws {
        let (repo, _, _) = try makeRepo(cachedAt: Fixtures.kyiv(2026, 11, 9, 10, 0))
        let snap = await repo.widgetSnapshot(allowsSelfRefresh: false)
        let p = SubgroupPresentation(snapshot: snap, subgroup: Fixtures.sg11, now: now)
        XCTAssertTrue(p.showsStaleWarning)
    }
}
