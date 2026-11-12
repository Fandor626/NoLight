import XCTest

final class RefreshStatusTests: XCTestCase {
    private let now = Fixtures.kyiv(2026, 11, 9, 22, 0)
    private var suite = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suite = "nl-status-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func repo(_ results: [URL: Result<String, ScheduleError>], status: RefreshStatusStore) -> ScheduleRepository {
        let n = now
        let service = ScheduleService(fetcher: MockFetcher(results: results), newsListURL: AppConfig.newsListURL, now: { n })
        let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("nl-\(UUID().uuidString).json")
        return ScheduleRepository(service: service, cache: FileScheduleCache(fileURL: cacheURL), now: { n }, status: status)
    }

    func testFailedRefreshIsRecorded() async {
        let status = RefreshStatusStore(defaults: defaults)
        do { _ = try await repo([AppConfig.newsListURL: .failure(.offline)], status: status).refresh() } catch {}
        XCTAssertEqual(status.lastFailure, RefreshFailure(at: now, message: ScheduleError.offline.message))
    }

    func testSuccessfulRefreshClearsFailure() async throws {
        let status = RefreshStatusStore(defaults: defaults)
        status.lastFailure = RefreshFailure(at: now.addingTimeInterval(-60), message: "x")
        let results: [URL: Result<String, ScheduleError>] = [
            AppConfig.newsListURL: .success(Fixtures.listHTML),
            Fixtures.url(Fixtures.slug10Update): .success(Fixtures.post10Nov),
            Fixtures.url(Fixtures.slug9): .success(Fixtures.post10Nov)]
        _ = try await repo(results, status: status).refresh()
        XCTAssertNil(status.lastFailure)
    }

    func testFailureMarkOnlyWhenNewerThanLastSuccess() {
        let failure = RefreshFailure(at: now, message: "x")
        XCTAssertTrue(failure.isNewer(than: now.addingTimeInterval(-60)))
        XCTAssertFalse(failure.isNewer(than: now.addingTimeInterval(60)))
        XCTAssertTrue(failure.isNewer(than: nil))
    }

    func testStoreRoundTripAndClear() {
        let status = RefreshStatusStore(defaults: defaults)
        status.lastFailure = RefreshFailure(at: now, message: "Немає підключення до інтернету.")
        XCTAssertEqual(RefreshStatusStore(defaults: defaults).lastFailure?.message, "Немає підключення до інтернету.")
        status.lastFailure = nil
        XCTAssertNil(RefreshStatusStore(defaults: defaults).lastFailure)
    }
}
