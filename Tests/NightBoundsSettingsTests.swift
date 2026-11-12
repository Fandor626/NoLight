import XCTest

final class NightBoundsSettingsTests: XCTestCase {
    private func makeStore() -> NightBoundsStore {
        let name = "NightBoundsSettingsTests-\(UUID().uuidString)"
        return NightBoundsStore(defaults: UserDefaults(suiteName: name)!)
    }

    func testDefaultWhenNothingSaved() {
        XCTAssertEqual(makeStore().bounds, .default)
    }

    func testSaveCustomBounds() {
        let store = makeStore()
        XCTAssertTrue(store.save(NightBounds(startMinute: 1320, endMinute: 420)))
        XCTAssertEqual(store.bounds, NightBounds(startMinute: 1320, endMinute: 420))
        store.reset()
        XCTAssertEqual(store.bounds, .default)
    }

    func testStartEqualsEndIsRejected() {
        let store = makeStore()
        store.save(NightBounds(startMinute: 60, endMinute: 300))
        let bad = NightBounds(startMinute: 600, endMinute: 600)
        XCTAssertNotNil(bad.validationMessage)
        XCTAssertFalse(store.save(bad))
        XCTAssertEqual(store.bounds, NightBounds(startMinute: 60, endMinute: 300), "Попередні межі лишаються")
        XCTAssertNil(NightBounds.default.validationMessage)
    }

    func testCorruptedStoredValuesFallBackToDefault() {
        let name = "NightBoundsSettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.set(2000, forKey: NightBoundsStore.startKey)
        defaults.set(10, forKey: NightBoundsStore.endKey)
        XCTAssertEqual(NightBoundsStore(defaults: defaults).bounds, .default)
    }

    func testStatisticsRecalculateWithCustomBounds() {
        let now = Fixtures.kyiv(2026, 11, 9, 22, 0)
        let snap = Fixtures.snapshot(posts: ["2026-11-08": ["1.1": [Fixtures.r(1320, 1440)]]], fetchedAt: now)
        let byDefault = StatisticsCalculator.statistics(snapshot: snap, subgroup: Fixtures.sg11, now: now, period: .three)
        XCTAssertEqual(byDefault.previousNightTotal.outage, 0)
        let custom = StatisticsCalculator.statistics(snapshot: snap, subgroup: Fixtures.sg11, now: now, period: .three,
                                                     night: NightBounds(startMinute: 1320, endMinute: 360))
        XCTAssertEqual(custom.previousNightTotal.outage, 120)
        XCTAssertEqual(custom.previousDayTotal.outage, 0)
    }

    func testNightTimeRoundTrip() {
        for minute in [0, 360, 1320, 1439] {
            XCTAssertEqual(NightTime.minute(of: NightTime.date(minute: minute, now: Fixtures.kyiv(2026, 11, 9, 12))), minute)
        }
    }
}
