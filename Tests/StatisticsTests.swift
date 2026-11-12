import XCTest

final class StatisticsTests: XCTestCase {
    private let now = Fixtures.kyiv(2026, 11, 9, 22, 0)

    func testPublishedDayCountsAvailableAndOutage() throws {
        let day = DaySchedule.build(dateKey: "2026-11-09", subgroup: Fixtures.sg11,
                                    outages: [Fixtures.r(0, 120), Fixtures.r(600, 840)], source: nil, publishedAt: nil)
        let m = try XCTUnwrap(StatisticsCalculator.minutes(of: day))
        XCTAssertEqual(m.outage, 360)
        XCTAssertEqual(m.available, 1080)
        XCTAssertEqual(m.unknown, 0)
    }

    func testUnknownMinutesAreSeparateNotAvailable() throws {
        let day = DaySchedule.build(dateKey: "2026-11-09", subgroup: Fixtures.sg11, outages: [Fixtures.r(0, 60)],
                                    unknown: [Fixtures.r(120, 180)], source: nil, publishedAt: nil)
        let m = try XCTUnwrap(StatisticsCalculator.minutes(of: day))
        XCTAssertEqual(m, PowerMinutes(available: 1320, outage: 60, unknown: 60))
    }

    func testDayWithoutDataIsUnknown() {
        for kind in [DayScheduleKind.notPublished, .noData, .parseFailed, .subgroupNotListed] {
            let day = DaySchedule.unknown(dateKey: "2026-11-09", subgroup: Fixtures.sg11, kind: kind)
            XCTAssertNil(StatisticsCalculator.minutes(of: day), "\(kind)")
        }
    }

    func testPlaceStatisticsExcludesUnknownDaysFromTotals() {
        let s = Fixtures.snapshot(posts: [
            "2026-11-09": ["1.1": [Fixtures.r(0, 240)]],
            "2026-11-08": ["1.1": [Fixtures.r(0, 120)]],
            "2026-11-06": ["1.1": [Fixtures.r(0, 60)]],
        ], fetchedAt: now)
        let stats = StatisticsCalculator.statistics(snapshot: s, subgroup: Fixtures.sg11, now: now, period: .three)
        XCTAssertEqual(stats.today.minutes?.outage, 240)
        XCTAssertNil(stats.tomorrow, "Завтра не опубліковано — не показуємо")
        XCTAssertEqual(stats.previous.map(\.dateKey), ["2026-11-08", "2026-11-07", "2026-11-06"])
        XCTAssertFalse(stats.previous[1].isKnown)
        XCTAssertEqual(stats.knownPreviousDays, 2)
        XCTAssertEqual(stats.unknownPreviousDays, 1)
        XCTAssertEqual(stats.previousTotal, PowerMinutes(available: 2880 - 180, outage: 180, unknown: 0))
    }

    func testTomorrowShownWhenPublished() {
        let s = Fixtures.snapshot(posts: [
            "2026-11-09": ["1.1": []],
            "2026-11-10": ["1.1": [Fixtures.r(480, 720)]],
        ], fetchedAt: now)
        let stats = StatisticsCalculator.statistics(snapshot: s, subgroup: Fixtures.sg11, now: now, period: .seven)
        XCTAssertEqual(stats.tomorrow?.minutes?.outage, 240)
        XCTAssertEqual(stats.today.minutes?.available, 1440)
        XCTAssertEqual(stats.previous.count, 7)
        XCTAssertEqual(stats.knownPreviousDays, 0)
        XCTAssertEqual(stats.previousTotal, PowerMinutes())
    }

    func testFourteenDayPeriod() {
        let stats = StatisticsCalculator.statistics(snapshot: nil, subgroup: Fixtures.sg11, now: now, period: .fourteen)
        XCTAssertEqual(stats.previous.count, 14)
        XCTAssertFalse(stats.today.isKnown)
    }

    // MARK: - DST (23 / 25 год)

    private var berlin: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return c
    }

    func testSpringForwardDayHas23Hours() throws {
        // 29.03.2026: 02:00 → 03:00 у Берліні, 02:00–03:00 не існує.
        let shift = try XCTUnwrap(StatisticsCalculator.dstShift(dateKey: "2026-03-29", calendar: berlin))
        XCTAssertEqual(shift.range, MinuteRange(start: 120, end: 180))
        XCTAssertEqual(shift.weight, 0)
        let day = DaySchedule.build(dateKey: "2026-03-29", subgroup: Fixtures.sg11, outages: [Fixtures.r(60, 180)],
                                    source: nil, publishedAt: nil)
        let m = try XCTUnwrap(StatisticsCalculator.minutes(of: day, calendar: berlin))
        XCTAssertEqual(m.total, 23 * 60)
        XCTAssertEqual(m.outage, 60)
    }

    func testFallBackDayHas25Hours() throws {
        // 25.10.2026: 03:00 → 02:00 у Берліні, 02:00–03:00 повторюється.
        let shift = try XCTUnwrap(StatisticsCalculator.dstShift(dateKey: "2026-10-25", calendar: berlin))
        XCTAssertEqual(shift.range, MinuteRange(start: 120, end: 180))
        XCTAssertEqual(shift.weight, 2)
        let day = DaySchedule.build(dateKey: "2026-10-25", subgroup: Fixtures.sg11, outages: [Fixtures.r(120, 240)],
                                    source: nil, publishedAt: nil)
        let m = try XCTUnwrap(StatisticsCalculator.minutes(of: day, calendar: berlin))
        XCTAssertEqual(m.total, 25 * 60)
        XCTAssertEqual(m.outage, 180)
    }

    func testOrdinaryDayHasNoShift() {
        XCTAssertNil(StatisticsCalculator.dstShift(dateKey: "2026-11-09", calendar: berlin))
        XCTAssertNil(StatisticsCalculator.dstShift(dateKey: "2026-11-09"))
    }

    func testKyivDayLengthMatchesCalendar() throws {
        // Не залежить від того, чи є в tzdata перехід для Києва: тривалість = реальна довжина доби.
        for key in ["2026-03-29", "2026-10-25", "2026-11-09"] {
            let day = DaySchedule.build(dateKey: key, subgroup: Fixtures.sg11, outages: [], source: nil, publishedAt: nil)
            let start = try XCTUnwrap(KyivTime.startOfDay(dateKey: key))
            let next = try XCTUnwrap(KyivTime.startOfDay(dateKey: KyivTime.addingDays(1, to: key)))
            XCTAssertEqual(StatisticsCalculator.minutes(of: day)?.total, Int(next.timeIntervalSince(start)) / 60, key)
        }
    }

    func testFormatting() {
        XCTAssertEqual(StatisticsFormat.duration(0), "0 год")
        XCTAssertEqual(StatisticsFormat.duration(45), "45 хв")
        XCTAssertEqual(StatisticsFormat.duration(750), "12 год 30 хв")
        XCTAssertEqual(StatisticsFormat.outageShare(PowerMinutes(available: 1080, outage: 360, unknown: 100)), 25)
        XCTAssertNil(StatisticsFormat.outageShare(PowerMinutes(unknown: 60)))
        XCTAssertEqual(StatisticsPeriod.three.title, "3 дні")
        XCTAssertEqual(StatisticsPeriod.fourteen.title, "14 днів")
    }
}
