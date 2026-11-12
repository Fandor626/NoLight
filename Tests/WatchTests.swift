import XCTest

final class TimelineWindowTests: XCTestCase {
    func testWindowIsFourHoursAroundNow() {
        let now = Fixtures.kyiv(2026, 11, 9, 16, 0)
        let snap = Fixtures.snapshot(posts: ["2026-11-09": ["1.1": [Fixtures.r(1020, 1140)]]], fetchedAt: now) // 17:00–19:00
        let w = TimelineWindow.make(snapshot: snap, subgroup: Fixtures.sg11, now: now)
        XCTAssertEqual(w.from, Fixtures.kyiv(2026, 11, 9, 14, 0))
        XCTAssertEqual(w.to, Fixtures.kyiv(2026, 11, 9, 18, 0))
        XCTAssertEqual(w.nowFraction, 0.5, accuracy: 1e-9)
        // 14:00–17:00 світло, 17:00–18:00 відключення.
        XCTAssertEqual(w.segments.count, 2)
        XCTAssertEqual(w.segments[0].state, .available)
        XCTAssertEqual(w.segments[0].end, 0.75, accuracy: 1e-9)
        XCTAssertEqual(w.segments[1].state, .outage)
        XCTAssertEqual(w.segments[1].end, 1, accuracy: 1e-9)
        XCTAssertEqual(w.changes, [0.75])
    }

    func testCrossingMidnightUsesTomorrowOrUnknown() {
        let now = Fixtures.kyiv(2026, 11, 9, 23, 0)
        let onlyToday = Fixtures.snapshot(posts: ["2026-11-09": ["1.1": []]], fetchedAt: now)
        let w = TimelineWindow.make(snapshot: onlyToday, subgroup: Fixtures.sg11, now: now)
        // 21:00–24:00 світло, 00:00–01:00 завтра не опубліковано → невідомо.
        XCTAssertEqual(w.segments.map(\.state), [.available, .unknown])
        XCTAssertEqual(w.segments[0].end, 0.75, accuracy: 1e-9)

        let withTomorrow = Fixtures.snapshot(posts: ["2026-11-09": ["1.1": []],
                                                     "2026-11-10": ["1.1": [Fixtures.r(0, 60)]]], fetchedAt: now)
        let w2 = TimelineWindow.make(snapshot: withTomorrow, subgroup: Fixtures.sg11, now: now)
        XCTAssertEqual(w2.segments.map(\.state), [.available, .outage])
    }

    func testEarlyMorningUsesYesterday() {
        let now = Fixtures.kyiv(2026, 11, 10, 1, 0)
        let snap = Fixtures.snapshot(posts: ["2026-11-09": ["1.1": [Fixtures.r(1380, 1440)]],   // 23:00–24:00
                                             "2026-11-10": ["1.1": []]], fetchedAt: now)
        let w = TimelineWindow.make(snapshot: snap, subgroup: Fixtures.sg11, now: now)
        XCTAssertEqual(w.from, Fixtures.kyiv(2026, 11, 9, 23, 0))
        XCTAssertEqual(w.segments.first?.state, .outage)
        XCTAssertEqual(w.segments.first?.end ?? 0, 0.25, accuracy: 1e-9)
    }

    func testExpiredDataIsAllUnknown() {
        let now = Fixtures.kyiv(2026, 11, 9, 16, 0)
        let old = Fixtures.snapshot(posts: ["2026-11-09": ["1.1": []]], fetchedAt: Fixtures.kyiv(2026, 11, 8, 10, 0))
        let w = TimelineWindow.make(snapshot: old, subgroup: Fixtures.sg11, now: now)
        XCTAssertEqual(w.segments, [TimelineWindowSegment(start: 0, end: 1, state: .unknown)])
        XCTAssertTrue(w.changes.isEmpty)
    }
}

final class WatchPayloadTests: XCTestCase {
    private func makeStore() -> WatchPlaceStore {
        WatchPlaceStore(defaults: UserDefaults(suiteName: "WatchPayloadTests-\(UUID().uuidString)")!)
    }

    private let home = Place(name: "Дім", subgroup: Fixtures.sg11)
    private let work = Place(name: "Робота", region: .lviv, subgroup: Fixtures.sg21, source: .outageDataAPI)

    func testRoundTripThroughApplicationContext() throws {
        var theme = ColorTheme.default
        theme.outage.dark = RGBAColor(hex: "#FF9F43")!
        let payload = WatchPayload(places: [home, work], preferredPlaceID: work.id, theme: theme,
                                   sentAt: Fixtures.kyiv(2026, 11, 12, 16, 0))
        let decoded = WatchPayload.decode(try payload.applicationContext())
        XCTAssertEqual(decoded, payload)
        XCTAssertNil(WatchPayload.decode([:]))
    }

    func testIphoneChoiceAppliesOnceThenWatchChoiceStays() {
        let store = makeStore()
        let payload = WatchPayload(places: [home, work], preferredPlaceID: work.id, theme: .default, sentAt: .now)
        XCTAssertEqual(store.apply(payload), work.id)
        store.placeID = home.id                     // вибрали на годиннику
        XCTAssertEqual(store.apply(payload), home.id, "Той самий вибір з iPhone не перекриває годинник")
        let newChoice = WatchPayload(places: [home, work], preferredPlaceID: home.id, theme: .default, sentAt: .now)
        store.placeID = work.id
        XCTAssertEqual(store.apply(newChoice), home.id, "Новий вибір на iPhone перекриває")
    }

    func testDeletedChosenPlaceFallsBackToFirst() {
        XCTAssertEqual(WatchPlaceStore.resolve(chosen: UUID(), places: [home, work]), home.id)
        XCTAssertNil(WatchPlaceStore.resolve(chosen: nil, places: []))
        XCTAssertEqual(WatchPlaceStore.resolve(chosen: work.id, places: [home, work]), work.id)
    }
}
