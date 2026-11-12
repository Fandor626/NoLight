import XCTest

final class ArrivalForecastTests: XCTestCase {
    private let now = Fixtures.kyiv(2026, 11, 9, 16, 0)

    /// Сьогодні: відключення 18:00–22:00. Завтра: відключення 00:00–02:00.
    private var snap: ScheduleSnapshot {
        Fixtures.snapshot(posts: [
            "2026-11-09": ["1.1": [Fixtures.r(1080, 1320)]],
            "2026-11-10": ["1.1": [Fixtures.r(0, 120)]],
        ], fetchedAt: now)
    }

    func testDurationFromNow() {
        let f = ArrivalCalculator.forecast(snapshot: snap, subgroup: Fixtures.sg11, now: now, input: .duration(minutes: 150))
        XCTAssertEqual(f.arrival, Fixtures.kyiv(2026, 11, 9, 18, 30))
        XCTAssertEqual(f.status.state, .outage)
        XCTAssertEqual(f.status.changeAt, Fixtures.kyiv(2026, 11, 9, 22, 0))
        XCTAssertEqual(f.status.nextState, .available)
        XCTAssertEqual(f.headline, "Світла не буде")
        XCTAssertEqual(f.detail(now: now), "Світло з’явиться о 22:00")
        XCTAssertEqual(f.arrivalText(now: now), "Приїзд сьогодні о 18:30")
    }

    func testArrivalTimeLaterToday() {
        let f = ArrivalCalculator.forecast(snapshot: snap, subgroup: Fixtures.sg11, now: now, input: .time(minute: 17 * 60))
        XCTAssertEqual(f.dayOffset, 0)
        XCTAssertEqual(f.status.state, .available)
        XCTAssertEqual(f.detail(now: now), "Далі відключення о 18:00")
    }

    func testArrivalTimeAlreadyPassedMeansTomorrow() {
        let f = ArrivalCalculator.forecast(snapshot: snap, subgroup: Fixtures.sg11, now: now, input: .time(minute: 60))
        XCTAssertEqual(f.arrival, Fixtures.kyiv(2026, 11, 10, 1, 0))
        XCTAssertEqual(f.dayOffset, 1)
        XCTAssertEqual(f.status.state, .outage)
        XCTAssertEqual(f.detail(now: now), "Світло з’явиться о 02:00 (завтра)")
        XCTAssertEqual(f.arrivalText(now: now), "Приїзд завтра о 01:00")
    }

    func testAfterMidnightWithoutTomorrowIsUnknown() {
        let onlyToday = Fixtures.snapshot(posts: ["2026-11-09": ["1.1": [Fixtures.r(1080, 1320)]]], fetchedAt: now)
        let f = ArrivalCalculator.forecast(snapshot: onlyToday, subgroup: Fixtures.sg11, now: now, input: .duration(minutes: 9 * 60))
        XCTAssertEqual(f.dayOffset, 1)
        XCTAssertEqual(f.status.state, .unknown)
        XCTAssertEqual(f.headline, "Невідомо")
        XCTAssertNotNil(f.detail(now: now))
    }

    func testBeyondTomorrowIsUnknown() {
        let f = ArrivalCalculator.forecast(snapshot: snap, subgroup: Fixtures.sg11, now: now, input: .duration(minutes: 40 * 60))
        XCTAssertEqual(f.dayOffset, 2)
        XCTAssertEqual(f.status.state, .unknown)
        XCTAssertEqual(f.detail(now: now), "Графіки публікують лише на сьогодні й завтра.")
    }

    func testExpiredDataIsUnknown() {
        let old = Fixtures.snapshot(posts: ["2026-11-09": ["1.1": []]], fetchedAt: Fixtures.kyiv(2026, 11, 8, 10, 0))
        let f = ArrivalCalculator.forecast(snapshot: old, subgroup: Fixtures.sg11, now: now, input: .duration(minutes: 60))
        XCTAssertEqual(f.status.state, .unknown)
    }

    func testDurationIsClamped() {
        XCTAssertEqual(ArrivalCalculator.arrivalDate(.duration(minutes: -5), now: now), now)
        XCTAssertEqual(ArrivalCalculator.arrivalDate(.duration(minutes: 100_000), now: now),
                       now.addingTimeInterval(TimeInterval(ArrivalCalculator.maxDurationMinutes * 60)))
    }
}
