import XCTest

final class DataLayerTests: XCTestCase {
    private let now = Fixtures.kyiv(2026, 11, 9, 22, 0)
    private var listURL: URL { AppConfig.newsListURL }

    private func service(_ results: [URL: Result<String, ScheduleError>]) -> ScheduleService {
        let n = now
        return ScheduleService(fetcher: MockFetcher(results: results), newsListURL: listURL, now: { n })
    }

    private var happyResults: [URL: Result<String, ScheduleError>] {
        [listURL: .success(Fixtures.listHTML),
         Fixtures.url(Fixtures.slug10Update): .success(Fixtures.post10Nov),
         Fixtures.url(Fixtures.slug9): .success(Fixtures.post10Nov)]
    }

    private func oldSnapshot() -> ScheduleSnapshot {
        Fixtures.snapshot(posts: ["2026-11-10": ["1.1": [Fixtures.r(0, 60)]]], fetchedAt: Fixtures.kyiv(2026, 11, 9, 18, 0))
    }

    func testFetchLatestBuildsSnapshot() async throws {
        let snapshot = try await service(happyResults).fetchLatest(previous: nil)
        XCTAssertEqual(snapshot.fetchedAt, now)
        XCTAssertEqual(snapshot.posts.keys.sorted(), ["2026-11-09", "2026-11-10"])
        XCTAssertEqual(snapshot.posts["2026-11-10"]?.outages["1.1"], Fixtures.outages11)
        XCTAssertEqual(snapshot.posts["2026-11-10"]?.sourceURL, Fixtures.url(Fixtures.slug10Update))
        XCTAssertTrue(snapshot.problemDates.isEmpty)
    }

    func testEmptyNewsListMeansStructureChanged() async {
        let svc = service([listURL: .success("<html><body>нічого</body></html>")])
        do { _ = try await svc.fetchLatest(previous: nil); XCTFail("Очікувалась помилка") }
        catch { XCTAssertEqual(error as? ScheduleError, .structureChanged) }
    }

    func testOfflineDuringListFetchPropagates() async {
        let svc = service([listURL: .failure(.offline)])
        do { _ = try await svc.fetchLatest(previous: nil); XCTFail("Очікувалась помилка") }
        catch { XCTAssertEqual(error as? ScheduleError, .offline) }
    }

    func testAllPostsUnparseableThrows() async {
        var results = happyResults
        results[Fixtures.url(Fixtures.slug10Update)] = .success("<p>нічого корисного</p>")
        results[Fixtures.url(Fixtures.slug9)] = .success("<p>нічого корисного</p>")
        do { _ = try await service(results).fetchLatest(previous: nil); XCTFail("Очікувалась помилка") }
        catch { guard case ScheduleError.parsingFailed = error else { return XCTFail("\(error)") } }
    }

    func testPartialFailureMarksProblemDateButKeepsGoodPost() async throws {
        var results = happyResults
        results[Fixtures.url(Fixtures.slug9)] = .success("<p>нічого корисного</p>")
        let snapshot = try await service(results).fetchLatest(previous: nil)
        XCTAssertEqual(snapshot.problemDates, ["2026-11-09"])
        XCTAssertNotNil(snapshot.posts["2026-11-10"])
        XCTAssertEqual(snapshot.schedule(for: Fixtures.sg11, dateKey: "2026-11-09").kind, .parseFailed)
        XCTAssertEqual(snapshot.schedule(for: Fixtures.sg11, dateKey: "2026-11-10").kind, .published)
    }

    func testCachedNewerPostIsNotRefetched() async throws {
        let cached = PublishedSchedulePost(dateKey: "2026-11-10", publishedAt: Fixtures.kyiv(2026, 11, 9, 23, 6),
                                           sourceURL: Fixtures.url(Fixtures.slug10Update), title: "x",
                                           outages: ["1.1": [Fixtures.r(0, 60)]], spillover: [:])
        let previous = ScheduleSnapshot(fetchedAt: Fixtures.kyiv(2026, 11, 9, 21, 0), posts: ["2026-11-10": cached])
        let results: [URL: Result<String, ScheduleError>] = [
            listURL: .success(Fixtures.listHTML),
            Fixtures.url(Fixtures.slug9): .success(Fixtures.post10Nov),
        ]
        let snapshot = try await service(results).fetchLatest(previous: previous)
        XCTAssertEqual(snapshot.posts["2026-11-10"], cached)
    }

    func testCacheRoundTrip() throws {
        let cache = FileScheduleCache(fileURL: makeTempCacheURL())
        XCTAssertNil(cache.load())
        let s = oldSnapshot()
        try cache.save(s)
        XCTAssertEqual(cache.load(), s)
    }

    func testCorruptedCacheLoadsAsNil() throws {
        let url = makeTempCacheURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{ це не json".utf8).write(to: url)
        XCTAssertNil(FileScheduleCache(fileURL: url).load())
    }

    func testCacheWithWrongVersionIsIgnored() throws {
        let url = makeTempCacheURL()
        let cache = FileScheduleCache(fileURL: url)
        try cache.save(oldSnapshot())
        var json = try String(contentsOf: url, encoding: .utf8)
        json = json.replacingOccurrences(of: "\"version\":1", with: "\"version\":99")
        try json.write(to: url, atomically: true, encoding: .utf8)
        XCTAssertNil(cache.load())
    }

    func testFailedRefreshDoesNotOverwriteCache() async throws {
        let cache = FileScheduleCache(fileURL: makeTempCacheURL())
        let old = oldSnapshot()
        try cache.save(old)
        let repo = ScheduleRepository(service: service([listURL: .failure(.offline)]), cache: cache)
        do { _ = try await repo.refresh(); XCTFail("Очікувалась помилка") }
        catch { XCTAssertEqual(error as? ScheduleError, .offline) }
        XCTAssertEqual(cache.load(), old)
    }

    func testInvalidSiteResponseDoesNotOverwriteCache() async throws {
        let cache = FileScheduleCache(fileURL: makeTempCacheURL())
        let old = oldSnapshot()
        try cache.save(old)
        let repo = ScheduleRepository(service: service([listURL: .success("<html>змінили верстку</html>")]), cache: cache)
        do { _ = try await repo.refresh(); XCTFail("Очікувалась помилка") }
        catch { XCTAssertEqual(error as? ScheduleError, .structureChanged) }
        XCTAssertEqual(cache.load(), old)
    }

    func testSuccessfulRefreshSavesAndNotifies() async throws {
        let cache = FileScheduleCache(fileURL: makeTempCacheURL())
        let notified = NotifyCounter()
        let repo = ScheduleRepository(service: service(happyResults), cache: cache, onUpdate: { notified.increment() })
        let snapshot = try await repo.refresh()
        XCTAssertEqual(cache.load(), snapshot)
        XCTAssertEqual(notified.value, 1)
        let cached = await repo.cachedSnapshot()
        XCTAssertEqual(cached, snapshot)
    }

    func testRefreshIfNeededUsesFreshCacheWithoutNetwork() async throws {
        let cache = FileScheduleCache(fileURL: makeTempCacheURL())
        let fresh = Fixtures.snapshot(posts: [:], fetchedAt: now.addingTimeInterval(-60))
        try cache.save(fresh)
        let n = now
        let repo = ScheduleRepository(service: service([:]), cache: cache, now: { n })
        let result = await repo.refreshIfNeeded(maxAge: 15 * 60)
        XCTAssertEqual(result, fresh)
    }

    func testRefreshIfNeededFallsBackToCacheOnFailure() async throws {
        let cache = FileScheduleCache(fileURL: makeTempCacheURL())
        let old = oldSnapshot()
        try cache.save(old)
        let n = now
        let repo = ScheduleRepository(service: service([listURL: .failure(.offline)]), cache: cache, now: { n })
        let result = await repo.refreshIfNeeded(maxAge: 15 * 60)
        XCTAssertEqual(result, old)
    }

    func testSnapshotSerializationRoundTrip() throws {
        let s = Fixtures.snapshot(posts: ["2026-11-10": ["1.1": Fixtures.outages11, "2.1": [Fixtures.r(1320, 1440)]]],
                                  spillover: ["2026-11-10": ["2.1": [Fixtures.r(0, 120)]]],
                                  fetchedAt: Fixtures.kyiv(2026, 11, 10, 12, 0))
        let data = try JSONEncoder().encode(s)
        let decoded = try JSONDecoder().decode(ScheduleSnapshot.self, from: data)
        XCTAssertEqual(decoded, s)
        XCTAssertEqual(decoded.schedule(for: Fixtures.sg11, dateKey: "2026-11-10"),
                       s.schedule(for: Fixtures.sg11, dateKey: "2026-11-10"))
    }

    func testSubgroupCodableAndParsing() throws {
        let data = try JSONEncoder().encode([Subgroup(id: "3.2")!])
        XCTAssertEqual(String(data: data, encoding: .utf8), "[\"3.2\"]")
        XCTAssertEqual(try JSONDecoder().decode([Subgroup].self, from: data), [Subgroup(queue: 3, sub: 2)!])
        XCTAssertNil(Subgroup(id: "7.1"))
        XCTAssertNil(Subgroup(id: "1.3"))
        XCTAssertNil(Subgroup(id: "abc"))
        XCTAssertEqual(Subgroup.all.count, 12)
        XCTAssertEqual(Subgroup.all.map { $0.id }.first, "1.1")
        XCTAssertEqual(Subgroup.all.map { $0.id }.last, "6.2")
    }

    func testSettingsStorePersistsSelection() {
        let suite = "cl-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.selectedSubgroups, [])
        store.selectedSubgroups = [Fixtures.sg21, Fixtures.sg11]
        XCTAssertEqual(SettingsStore(defaults: defaults).selectedSubgroups, [Fixtures.sg21, Fixtures.sg11])
    }
}

final class NotifyCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func increment() { lock.lock(); count += 1; lock.unlock() }
    var value: Int { lock.lock(); defer { lock.unlock() }; return count }
}
