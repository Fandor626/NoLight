import XCTest

final class NightDaySplitTests: XCTestCase {
    private let now = Fixtures.kyiv(2026, 11, 9, 22, 0)

    private func day(_ outages: [MinuteRange], unknown: [MinuteRange] = []) -> DaySchedule {
        DaySchedule.build(dateKey: "2026-11-09", subgroup: Fixtures.sg11, outages: outages, unknown: unknown,
                          source: nil, publishedAt: nil)
    }

    func testDefaultNightIsMidnightToSix() {
        XCTAssertEqual(NightBounds.default.ranges, [Fixtures.r(0, 360)])
        XCTAssertEqual(NightBounds.default.dayRanges, [Fixtures.r(360, 1440)])
        XCTAssertEqual(NightBounds.default.title, "00:00–06:00")
    }

    func testDefaultSplit() throws {
        // Відключення 04:00–08:00: 2 год уночі, 2 год удень.
        let s = StatisticsCalculator.day(day([Fixtures.r(240, 480)]))
        XCTAssertEqual(s.night, PowerMinutes(available: 240, outage: 120, unknown: 0))
        XCTAssertEqual(s.daytime, PowerMinutes(available: 960, outage: 120, unknown: 0))
        XCTAssertEqual(s.minutes, try XCTUnwrap(s.night) + XCTUnwrap(s.daytime))
    }

    func testNightCrossingMidnight() throws {
        let bounds = NightBounds(startMinute: 1320, endMinute: 360) // 22:00–06:00
        XCTAssertTrue(bounds.crossesMidnight)
        XCTAssertEqual(bounds.ranges, [Fixtures.r(0, 360), Fixtures.r(1320, 1440)])
        XCTAssertEqual(bounds.dayRanges, [Fixtures.r(360, 1320)])
        // Відключення 00:00–02:00 і 20:00–24:00: уночі 2 + 2 год, удень 2 год.
        let s = StatisticsCalculator.day(day([Fixtures.r(0, 120), Fixtures.r(1200, 1440)]), night: bounds)
        XCTAssertEqual(s.night?.outage, 240)
        XCTAssertEqual(s.night?.total, 480)
        XCTAssertEqual(s.daytime?.outage, 120)
        XCTAssertEqual(s.daytime?.total, 960)
    }

    func testNightEndingAtMidnight() {
        let bounds = NightBounds(startMinute: 1320, endMinute: 0) // 22:00–00:00
        XCTAssertEqual(bounds.ranges, [Fixtures.r(1320, 1440)])
        XCTAssertEqual(bounds.dayRanges, [Fixtures.r(0, 1320)])
    }

    func testInvalidBoundsFallBackToDefault() {
        let bad = NightBounds(startMinute: 300, endMinute: 300)
        XCTAssertFalse(bad.isValid)
        XCTAssertEqual(bad.ranges, [])
        let s = StatisticsCalculator.day(day([Fixtures.r(0, 60)]), night: bad)
        XCTAssertEqual(s.night?.total, 360)
    }

    func testUnknownMinutesStaySeparateInSplit() {
        let s = StatisticsCalculator.day(day([], unknown: [Fixtures.r(300, 420)]))
        XCTAssertEqual(s.night, PowerMinutes(available: 300, outage: 0, unknown: 60))
        XCTAssertEqual(s.daytime, PowerMinutes(available: 1020, outage: 0, unknown: 60))
    }

    func testDayWithoutDataHasNoSplit() {
        let s = StatisticsCalculator.day(.unknown(dateKey: "2026-11-09", subgroup: Fixtures.sg11, kind: .noData))
        XCTAssertNil(s.night)
        XCTAssertNil(s.daytime)
    }

    func testPeriodTotalsSplit() {
        let snap = Fixtures.snapshot(posts: [
            "2026-11-08": ["1.1": [Fixtures.r(0, 120)]],      // ніч 2 год
            "2026-11-07": ["1.1": [Fixtures.r(600, 840)]],    // день 4 год
        ], fetchedAt: now)
        let stats = StatisticsCalculator.statistics(snapshot: snap, subgroup: Fixtures.sg11, now: now, period: .three)
        XCTAssertEqual(stats.previousNightTotal.outage, 120)
        XCTAssertEqual(stats.previousDayTotal.outage, 240)
        XCTAssertEqual(stats.previousNightTotal + stats.previousDayTotal, stats.previousTotal)
    }
}
