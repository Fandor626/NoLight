import XCTest

final class LiveActivityRestoreTests: XCTestCase {
    private let now = Fixtures.kyiv(2026, 11, 12, 16, 0)
    private let home = UUID(), work = UUID(), gone = UUID()

    func testDismissedKeptActivityIsStartedAgain() {
        let plan = LiveActivityRestorePlanner.plan(kept: [home], running: [:], placeIDs: [home, work], now: now)
        XCTAssertEqual(plan.start, [home])
        XCTAssertTrue(plan.renew.isEmpty)
    }

    func testRunningFreshActivityIsLeftAlone() {
        let plan = LiveActivityRestorePlanner.plan(kept: [home], running: [home: now.addingTimeInterval(-3600)],
                                                   placeIDs: [home], now: now)
        XCTAssertEqual(plan, LiveActivityRestorePlan())
    }

    func testActivityNearEightHoursIsRenewed() {
        let plan = LiveActivityRestorePlanner.plan(kept: [home], running: [home: now.addingTimeInterval(-7.6 * 3600)],
                                                   placeIDs: [home], now: now)
        XCTAssertEqual(plan.renew, [home])
        XCTAssertTrue(plan.start.isEmpty)
    }

    func testStoppedInAppIsNotRestored() {
        // Зупинили в застосунку → місця немає в kept → нічого не запускаємо.
        let plan = LiveActivityRestorePlanner.plan(kept: [], running: [:], placeIDs: [home, work], now: now)
        XCTAssertEqual(plan, LiveActivityRestorePlan())
    }

    func testDeletedPlaceIsForgotten() {
        let plan = LiveActivityRestorePlanner.plan(kept: [home, gone], running: [:], placeIDs: [home], now: now)
        XCTAssertEqual(plan.forget, [gone])
        XCTAssertEqual(plan.start, [home])
    }

    func testKeepStorePersistsInAppGroupDefaults() {
        let defaults = UserDefaults(suiteName: "LiveActivityRestoreTests-\(UUID().uuidString)")!
        let store = LiveActivityKeepStore(defaults: defaults)
        XCTAssertTrue(store.placeIDs.isEmpty)
        store.add(home)
        store.add(work)
        XCTAssertTrue(LiveActivityKeepStore(defaults: defaults).contains(home))
        store.remove(home)
        XCTAssertEqual(LiveActivityKeepStore(defaults: defaults).placeIDs, [work])
    }
}
