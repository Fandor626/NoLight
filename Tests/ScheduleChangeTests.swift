import XCTest

final class ScheduleChangeTests: XCTestCase {
    private let today = "2026-11-10", tomorrow = "2026-11-11"
    private let now = Fixtures.kyiv(2026, 11, 10, 9, 0)
    private let place = Place(name: "Робота", subgroup: Fixtures.sg11)

    private func snap(_ todayOutages: [MinuteRange], tomorrowOutages: [MinuteRange]? = nil) -> ScheduleSnapshot {
        var posts: [String: [String: [MinuteRange]]] = [today: ["1.1": todayOutages]]
        if let t = tomorrowOutages { posts[tomorrow] = ["1.1": t] }
        return Fixtures.snapshot(posts: posts, fetchedAt: now)
    }

    private func detect(_ s: ScheduleSnapshot, _ seen: inout SeenSchedules, places: [Place]? = nil) -> [ScheduleChange] {
        ScheduleChangeDetector.detect(places: places ?? [place], snapshot: { _ in s }, seen: &seen, now: now)
    }

    func testFirstSightIsNotAChange() {
        var seen: SeenSchedules = [:]
        XCTAssertTrue(detect(snap([Fixtures.r(600, 720)]), &seen).isEmpty)
        XCTAssertEqual(seen[place.id.uuidString]?[today], [Fixtures.r(600, 720)])
    }

    func testChangedIntervalsAreDetectedOnce() {
        var seen: SeenSchedules = [:]
        _ = detect(snap([Fixtures.r(600, 720)]), &seen)
        let changes = detect(snap([Fixtures.r(600, 780)]), &seen)
        XCTAssertEqual(changes, [ScheduleChange(placeID: place.id, dateKey: today, detectedAt: now,
                                                old: [Fixtures.r(600, 720)], new: [Fixtures.r(600, 780)])])
        XCTAssertTrue(detect(snap([Fixtures.r(600, 780)]), &seen).isEmpty)   // без змін — без сповіщення
    }

    func testNewlyPublishedTomorrowIsNotAChange() {
        var seen: SeenSchedules = [:]
        _ = detect(snap([Fixtures.r(600, 720)]), &seen)
        XCTAssertTrue(detect(snap([Fixtures.r(600, 720)], tomorrowOutages: [Fixtures.r(0, 60)]), &seen).isEmpty)
        XCTAssertEqual(detect(snap([Fixtures.r(600, 720)], tomorrowOutages: [Fixtures.r(0, 120)]), &seen).map(\.dateKey),
                       [tomorrow])
    }

    func testDeletedPlacesAndOldDaysArePruned() {
        var seen: SeenSchedules = ["\(UUID().uuidString)": [today: []],
                                   place.id.uuidString: ["2026-10-01": [], today: [Fixtures.r(0, 60)]]]
        _ = detect(snap([Fixtures.r(0, 60)]), &seen)
        XCTAssertEqual(Array(seen.keys), [place.id.uuidString])
        XCTAssertNil(seen[place.id.uuidString]?["2026-10-01"])
    }

    func testMessage() {
        let change = ScheduleChange(placeID: place.id, dateKey: today, detectedAt: now,
                                    old: [Fixtures.r(600, 720)], new: [Fixtures.r(600, 780), Fixtures.r(1080, 1200)])
        let m = ScheduleChangeDetector.message(for: change, placeName: "Робота", now: now)
        XCTAssertEqual(m.title, "Графік для «Робота» змінився")
        XCTAssertEqual(m.body, "Сьогодні: відключення 10:00–13:00, 18:00–20:00 (було: відключення 10:00–12:00).")
        XCTAssertEqual(ScheduleChangeDetector.describe([]), "відключень немає")
    }

    func testSeenStoreRoundTrip() {
        let suite = "nl-seen-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        ScheduleSeenStore(defaults: defaults).seen = ["a": [today: [Fixtures.r(0, 60)]]]
        XCTAssertEqual(ScheduleSeenStore(defaults: defaults).seen["a"]?[today], [Fixtures.r(0, 60)])
    }

    func testNotifyIsOffByDefault() {
        XCTAssertFalse(place.notifiesScheduleChanges)
    }
}
