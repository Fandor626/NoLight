import XCTest

final class ParserTests: XCTestCase {
    func testParsesAllTwelveSubgroupsFromRealPost() throws {
        let parsed = try ScheduleParser.parsePost(html: Fixtures.post10Nov)
        XCTAssertEqual(parsed.outages.count, 12)
        XCTAssertEqual(parsed.outages["1.1"], Fixtures.outages11)
        XCTAssertEqual(parsed.outages["3.1"], [Fixtures.r(0, 240), Fixtures.r(360, 600), Fixtures.r(720, 960), Fixtures.r(1080, 1320)])
        XCTAssertEqual(parsed.outages["5.2"], [Fixtures.r(0, 60), Fixtures.r(180, 420), Fixtures.r(540, 780), Fixtures.r(900, 1140), Fixtures.r(1260, 1440)])
        XCTAssertTrue(parsed.spillover.isEmpty)
    }

    func testIgnoresHeadMetaContent() throws {
        let parsed = try ScheduleParser.parsePost(html: Fixtures.post10Nov)
        XCTAssertFalse(parsed.outages["1.1"]!.contains(Fixtures.r(300, 360)))
    }

    func testTitleInfo() {
        XCTAssertEqual(ScheduleParser.titleInfo("Оновлено графік погодинних відключень (ГПВ) на 10 листопада"),
                       .init(day: 10, month: 11, isUpdate: true))
        XCTAssertEqual(ScheduleParser.titleInfo("Графік погодинних відключень (ГПВ) на 9 листопада"),
                       .init(day: 9, month: 11, isUpdate: false))
        XCTAssertNil(ScheduleParser.titleInfo("Для промисловості та бізнесу Черкаської області 10 листопада діятимуть графіки обмеження потужності (ГОП)"))
        XCTAssertNil(ScheduleParser.titleInfo("Прогнозні обсяги обмеження та відключення електроенергії на 01 листопада 2026 року"))
    }

    func testNewsListParsing() {
        let items = ScheduleParser.parseNewsList(html: Fixtures.listHTML, baseURL: AppConfig.newsListURL)
        XCTAssertEqual(items.count, 4)
        XCTAssertEqual(items[0].title, "Оновлено графік погодинних відключень (ГПВ) на 10 листопада")
        XCTAssertEqual(items[0].url, Fixtures.url(Fixtures.slug10Update))
        XCTAssertEqual(items[0].publishedAt, Fixtures.kyiv(2026, 11, 9, 23, 6))
        XCTAssertEqual(items[1].publishedAt, Fixtures.kyiv(2026, 11, 9, 20, 58))
        XCTAssertEqual(items[3].publishedAt, Fixtures.kyiv(2026, 11, 8, 23, 3))
    }

    func testNewsListWithoutMediaLinksIsEmpty() {
        XCTAssertTrue(ScheduleParser.parseNewsList(html: "<html><body>порожньо</body></html>", baseURL: AppConfig.newsListURL).isEmpty)
    }

    func testToleratesDashVariantsSpacesAndNbsp() throws {
        let parsed = try ScheduleParser.parsePost(html: "<p>1.1 00 :00 – 02:00 , 04:00 — 08:00</p><p>1.2&nbsp;01:00&nbsp;-&nbsp;03:00</p>")
        XCTAssertEqual(parsed.outages["1.1"], [Fixtures.r(0, 120), Fixtures.r(240, 480)])
        XCTAssertEqual(parsed.outages["1.2"], [Fixtures.r(60, 180)])
    }

    func testSplitsSubgroupsWrittenOnOneLine() throws {
        let parsed = try ScheduleParser.parsePost(html: "<p>1.1 00:00 - 02:00 1.2 03:00 - 04:00</p>")
        XCTAssertEqual(parsed.outages["1.1"], [Fixtures.r(0, 120)])
        XCTAssertEqual(parsed.outages["1.2"], [Fixtures.r(180, 240)])
    }

    func testMergesOverlappingAndAdjacentRanges() throws {
        let parsed = try ScheduleParser.parsePost(html: "<p>1.1 00:00 - 02:00, 02:00 - 03:00, 02:30 - 04:00</p>")
        XCTAssertEqual(parsed.outages["1.1"], [Fixtures.r(0, 240)])
    }

    func testMidnightCrossingRangeIsSplitIntoSpillover() throws {
        let parsed = try ScheduleParser.parsePost(html: "<p>2.1 22:00 - 02:00</p>")
        XCTAssertEqual(parsed.outages["2.1"], [Fixtures.r(1320, 1440)])
        XCTAssertEqual(parsed.spillover["2.1"], [Fixtures.r(0, 120)])
    }

    func testInvalidTimeIsRejected() {
        XCTAssertThrowsError(try ScheduleParser.parsePost(html: "<p>1.1 25:00 - 26:00</p>")) { error in
            guard case ScheduleError.invalidData = error else { return XCTFail("Неочікувана помилка: \(error)") }
        }
        XCTAssertThrowsError(try ScheduleParser.parsePost(html: "<p>1.1 10:00 - 10:00</p>"))
        XCTAssertThrowsError(try ScheduleParser.parsePost(html: "<p>1.1 10:75 - 11:00</p>"))
    }

    func testUnsupportedFormatIsRejectedNotGuessed() {
        let html = "<p>16:00-17:00 5 та 1 черги</p><p>17:00-18:00 2 та 3 черги</p>"
        XCTAssertThrowsError(try ScheduleParser.parsePost(html: html)) { error in
            guard case ScheduleError.parsingFailed = error else { return XCTFail("Неочікувана помилка: \(error)") }
        }
    }

    func testDateLineIsNotMistakenForSubgroup() throws {
        let parsed = try ScheduleParser.parsePost(html: "<p>09.11.2026 23:06</p><p>1.1 00:00 - 01:00</p>")
        XCTAssertEqual(parsed.outages.keys.sorted(), ["1.1"])
    }

    func testSelectorPicksNewestPostPerDayAndSkipsGOP() {
        let items = ScheduleParser.parseNewsList(html: Fixtures.listHTML, baseURL: AppConfig.newsListURL)
        let selected = ScheduleSelector.select(items, now: Fixtures.kyiv(2026, 11, 9, 22, 0))
        XCTAssertEqual(selected.map { $0.dateKey }, ["2026-11-09", "2026-11-10"])
        XCTAssertEqual(selected[1].item.url, Fixtures.url(Fixtures.slug10Update))
        XCTAssertEqual(selected[0].item.url, Fixtures.url(Fixtures.slug9))
    }

    func testSelectorSkipsPastDays() {
        let items = ScheduleParser.parseNewsList(html: Fixtures.listHTML, baseURL: AppConfig.newsListURL)
        let selected = ScheduleSelector.select(items, now: Fixtures.kyiv(2026, 11, 10, 12, 0))
        XCTAssertEqual(selected.map { $0.dateKey }, ["2026-11-10"])
    }

    func testYearInferenceAcrossNewYear() {
        let ref = Fixtures.kyiv(2026, 12, 31, 22, 0)
        XCTAssertEqual(KyivTime.dateKey(day: 1, month: 1, reference: ref), "2027-01-01")
        XCTAssertEqual(KyivTime.dateKey(day: 30, month: 12, reference: ref), "2026-12-30")
        XCTAssertNil(KyivTime.dateKey(day: 31, month: 2, reference: ref))
    }
}
