import XCTest

final class WatchComplicationTests: XCTestCase {
    private let now = Fixtures.kyiv(2026, 11, 9, 16, 0)

    private func p(_ outages: [MinuteRange], tomorrow: [MinuteRange]? = nil) -> SubgroupPresentation {
        var posts = ["2026-11-09": ["1.1": outages]]
        if let tomorrow { posts["2026-11-10"] = ["1.1": tomorrow] }
        return SubgroupPresentation(snapshot: Fixtures.snapshot(posts: posts, fetchedAt: now), subgroup: Fixtures.sg11, now: now)
    }

    func testInlineTexts() {
        XCTAssertEqual(WatchComplication.inline(p([Fixtures.r(1080, 1260)]).status, now: now), "Світло до 18:00")
        XCTAssertEqual(WatchComplication.inline(p([Fixtures.r(900, 1230)]).status, now: now), "Без світла до 20:30")
        XCTAssertEqual(WatchComplication.inline(p([], tomorrow: [Fixtures.r(60, 120)]).status, now: now),
                       "Світло до 01:00 (завтра)")
        XCTAssertEqual(WatchComplication.inline(PowerStatus(state: .unknown, changeAt: nil, nextState: nil), now: now),
                       "Світло: невідомо")
    }

    func testInlineMidnightIs2400() {
        // Сьогодні без відключень, завтра не опубліковано → зміна на «невідомо» о 24:00.
        XCTAssertEqual(WatchComplication.inline(p([]).status, now: now), "Світло до 24:00")
    }

    func testProgressOfCurrentInterval() throws {
        // Світло 12:00–18:00 (між відключеннями) → о 16:00 минуло 4 з 6 год.
        let pres = p([Fixtures.r(600, 720), Fixtures.r(1080, 1200)])
        let progress = try XCTUnwrap(WatchComplication.progress(today: pres.today, tomorrow: pres.tomorrow, now: now))
        XCTAssertEqual(progress, 4.0 / 6.0, accuracy: 1e-9)
    }

    func testRelevanceIsHighShortlyBeforeChange() {
        XCTAssertEqual(WatchComplication.relevance(changeAt: now.addingTimeInterval(20 * 60), now: now), 1.0)
        XCTAssertEqual(WatchComplication.relevance(changeAt: now.addingTimeInterval(3 * 3600), now: now), 0.2)
        XCTAssertEqual(WatchComplication.relevance(changeAt: nil, now: now), 0.1)
    }
}
