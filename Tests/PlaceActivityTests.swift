import XCTest

final class PlaceActivityTests: XCTestCase {
    private let now = Fixtures.kyiv(2026, 11, 9, 16, 0)

    private func presentation(_ outages: [MinuteRange], tomorrow: [MinuteRange]? = nil) -> SubgroupPresentation {
        var posts = ["2026-11-09": ["1.1": outages]]
        if let tomorrow { posts["2026-11-10"] = ["1.1": tomorrow] }
        return SubgroupPresentation(snapshot: Fixtures.snapshot(posts: posts, fetchedAt: now),
                                    subgroup: Fixtures.sg11, now: now)
    }

    func testContentHasStateAndNextChange() {
        let c = PlaceActivityPlanner.content(presentation: presentation([Fixtures.r(1080, 1320)]), startedAt: now)
        XCTAssertEqual(c.state, .available)
        XCTAssertEqual(c.changeAt, Fixtures.kyiv(2026, 11, 9, 18, 0))
        XCTAssertEqual(c.nextState, .outage)
        XCTAssertEqual(PlaceActivityPlanner.headline(c), "Світло є")
        XCTAssertEqual(PlaceActivityPlanner.countdownTitle(c), "До відключення")
        XCTAssertEqual(c.updatedAt, now)
    }

    func testOutageCountsDownToPowerReturn() {
        let c = PlaceActivityPlanner.content(presentation: presentation([Fixtures.r(900, 1020)]), startedAt: now)
        XCTAssertEqual(c.state, .outage)
        XCTAssertEqual(PlaceActivityPlanner.countdownTitle(c), "До появи світла")
        XCTAssertEqual(c.changeAt, Fixtures.kyiv(2026, 11, 9, 17, 0))
    }

    func testStaleAtChangeOrAfterEightHours() {
        let soon = PlaceActivityPlanner.content(presentation: presentation([Fixtures.r(1080, 1320)]), startedAt: now)
        XCTAssertEqual(PlaceActivityPlanner.staleDate(soon), Fixtures.kyiv(2026, 11, 9, 18, 0))
        var late = soon
        late.changeAt = Fixtures.kyiv(2026, 11, 10, 6, 0)
        XCTAssertEqual(PlaceActivityPlanner.staleDate(late), now.addingTimeInterval(8 * 3600))
        var none = soon
        none.changeAt = nil
        XCTAssertEqual(PlaceActivityPlanner.staleDate(none), PlaceActivityPlanner.endDate(startedAt: now))
    }

    func testExpiresAfterEightHoursAndOffersRestart() {
        let c = PlaceActivityPlanner.content(presentation: presentation([]), startedAt: now)
        XCTAssertFalse(PlaceActivityPlanner.isExpired(startedAt: now, now: now.addingTimeInterval(8 * 3600 - 1)))
        XCTAssertTrue(PlaceActivityPlanner.isExpired(startedAt: now, now: now.addingTimeInterval(8 * 3600)))
        XCTAssertEqual(PlaceActivityPlanner.fallbackText(c, isStale: true, now: now.addingTimeInterval(9 * 3600)),
                       "Відлік завершено. Натисніть, щоб запустити знову.")
    }

    func testFallbackTexts() {
        let free = PlaceActivityPlanner.content(presentation: presentation([], tomorrow: []), startedAt: now)
        XCTAssertEqual(free.changeAt, nil)
        XCTAssertNil(PlaceActivityPlanner.countdownTitle(free))
        XCTAssertEqual(PlaceActivityPlanner.fallbackText(free, isStale: false, now: now), "Відключень не заплановано")
        XCTAssertEqual(PlaceActivityPlanner.fallbackText(free, isStale: true, now: now),
                       "Відкрийте застосунок, щоб оновити відлік.")
        let unknown = PlaceActivityPlanner.content(
            presentation: SubgroupPresentation(snapshot: nil, subgroup: Fixtures.sg11, now: now), startedAt: now)
        XCTAssertEqual(PlaceActivityPlanner.headline(unknown), "Невідомо")
        XCTAssertEqual(PlaceActivityPlanner.fallbackText(unknown, isStale: false, now: now), "Графік невідомий")
    }

    func testUnknownTomorrowCountsToEndOfKnownSchedule() {
        // Сьогодні без відключень, завтра не опубліковано → зміна о 24:00 на «невідомо».
        let c = PlaceActivityPlanner.content(presentation: presentation([]), startedAt: now)
        XCTAssertEqual(c.nextState, .unknown)
        XCTAssertEqual(PlaceActivityPlanner.countdownTitle(c), "До кінця відомого графіка")
    }
}
