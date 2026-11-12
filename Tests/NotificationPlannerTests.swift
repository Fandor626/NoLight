import XCTest

final class NotificationPlannerTests: XCTestCase {
    private let day = "2026-11-10", next = "2026-11-11"
    private let fetched = Fixtures.kyiv(2026, 11, 10, 7, 0)

    private func snapshot() -> ScheduleSnapshot {
        // 1.1: відключення 10:00–12:00 і 18:00–20:00 сьогодні, 02:00–03:00 завтра.
        Fixtures.snapshot(posts: [day: ["1.1": [Fixtures.r(600, 720), Fixtures.r(1080, 1200)]],
                                  next: ["1.1": [Fixtures.r(120, 180)]]], fetchedAt: fetched)
    }

    private func place(_ lead: Int?) -> Place {
        var p = Place(name: "Робота", subgroup: Fixtures.sg11)
        p.warnBeforeOutageMinutes = lead
        return p
    }

    func testPlansWarningsBeforeEachUpcomingOutage() {
        let p = place(15)
        let s = snapshot()
        let plan = NotificationPlanner.plan(places: [p], snapshot: { _ in s }, now: Fixtures.kyiv(2026, 11, 10, 8, 0))
        XCTAssertEqual(plan.map(\.fireDate), [Fixtures.kyiv(2026, 11, 10, 9, 45),
                                              Fixtures.kyiv(2026, 11, 10, 17, 45),
                                              Fixtures.kyiv(2026, 11, 11, 1, 45)])
        XCTAssertEqual(plan.first?.title, "«Робота»: відключення о 10:00")
        XCTAssertEqual(plan.first?.body, "Через 15 хв за графіком не буде світла (підчерга 1.1).")
        XCTAssertTrue(plan.allSatisfy { $0.id.hasPrefix("nolight.\(p.id.uuidString).outage.") })
    }

    func testWarningsAreOffByDefault() {
        let s = snapshot()
        XCTAssertTrue(NotificationPlanner.plan(places: [place(nil)], snapshot: { _ in s },
                                               now: Fixtures.kyiv(2026, 11, 10, 8, 0)).isEmpty)
    }

    func testPastAndAlreadyStartedOutagesAreSkipped() {
        let s = snapshot()
        // 09:50: попередження о 09:45 уже минуло; поточне відключення не плануємо.
        let plan = NotificationPlanner.plan(places: [place(15)], snapshot: { _ in s }, now: Fixtures.kyiv(2026, 11, 10, 9, 50))
        XCTAssertEqual(plan.first?.eventDate, Fixtures.kyiv(2026, 11, 10, 18, 0))
    }

    func testLimitKeepsNearest() {
        let s = snapshot()
        let places = (0..<30).map { _ in place(15) }   // 30 місць × 3 = 90 > 64
        let plan = NotificationPlanner.plan(places: places, snapshot: { _ in s }, now: Fixtures.kyiv(2026, 11, 10, 8, 0))
        XCTAssertEqual(plan.count, NotificationPlanner.iOSLimit)
        XCTAssertEqual(plan.filter { $0.fireDate == Fixtures.kyiv(2026, 11, 10, 9, 45) }.count, 30)
        XCTAssertEqual(plan.map(\.fireDate), plan.map(\.fireDate).sorted())
    }

    func testNoDataMeansNoWarnings() {
        let plan = NotificationPlanner.plan(places: [place(15)], snapshot: { _ in nil }, now: Fixtures.kyiv(2026, 11, 10, 8, 0))
        XCTAssertTrue(plan.isEmpty)
    }

    func testDiffRemovesDeletedPlaceAndChangedSchedule() {
        let s = snapshot()
        let p = place(15)
        let plan = NotificationPlanner.plan(places: [p], snapshot: { _ in s }, now: Fixtures.kyiv(2026, 11, 10, 8, 0))
        let stale = "nolight.\(UUID().uuidString).outage.1"   // видалене місце / старий графік
        let foreign = "other-app-request"
        let d = NotificationPlanner.diff(pendingIDs: [plan[0].id, stale, foreign], plan: plan)
        XCTAssertEqual(d.remove, [stale])                   // чужі сповіщення не чіпаємо
        XCTAssertEqual(d.add.map(\.id), Array(plan.dropFirst()).map(\.id))
    }

    // NOL-22
    func testPowerReturnWarningsUseTheirOwnLeadTime() {
        var p = place(nil)
        p.warnBeforeReturnMinutes = 30
        let s = snapshot()
        let plan = NotificationPlanner.plan(places: [p], snapshot: { _ in s }, now: Fixtures.kyiv(2026, 11, 10, 8, 0))
        XCTAssertEqual(plan.map(\.kind), [.powerReturn, .powerReturn, .powerReturn])
        XCTAssertEqual(plan.map(\.fireDate), [Fixtures.kyiv(2026, 11, 10, 11, 30),
                                              Fixtures.kyiv(2026, 11, 10, 19, 30),
                                              Fixtures.kyiv(2026, 11, 11, 2, 30)])
        XCTAssertEqual(plan.first?.title, "«Робота»: світло о 12:00")
    }

    func testBothKindsShareTheLimitAndAreSorted() {
        var p = place(15)
        p.warnBeforeReturnMinutes = 10
        let s = snapshot()
        let plan = NotificationPlanner.plan(places: [p], snapshot: { _ in s }, now: Fixtures.kyiv(2026, 11, 10, 8, 0), limit: 4)
        XCTAssertEqual(plan.map(\.kind), [.outage, .powerReturn, .outage, .powerReturn])
        XCTAssertEqual(plan.map(\.fireDate), plan.map(\.fireDate).sorted())
    }

    func testNoPowerReturnWhenTurnedOff() {
        let s = snapshot()
        let plan = NotificationPlanner.plan(places: [place(15)], snapshot: { _ in s }, now: Fixtures.kyiv(2026, 11, 10, 8, 0))
        XCTAssertFalse(plan.contains { $0.kind == .powerReturn })
    }

    func testOutageEndingInUnknownIsNotAPowerReturn() {
        var p = place(nil)
        p.warnBeforeReturnMinutes = 15
        // Відключення до 24:00, а завтра графіка немає → після відключення «невідомо», не «світло».
        let s = Fixtures.snapshot(posts: [day: ["1.1": [Fixtures.r(1320, 1440)]]], fetchedAt: fetched)
        let plan = NotificationPlanner.plan(places: [p], snapshot: { _ in s }, now: Fixtures.kyiv(2026, 11, 10, 8, 0))
        XCTAssertTrue(plan.isEmpty)
    }

    func testOldStoredPlaceWithoutWarningFieldDecodes() throws {
        let json = #"{"id":"\#(UUID().uuidString)","name":"Дім","region":"cherkasy","subgroup":"3.2","source":"oblenergoSite"}"#
        let p = try JSONDecoder().decode(Place.self, from: Data(json.utf8))
        XCTAssertNil(p.warnBeforeOutageMinutes)
        XCTAssertNil(p.warnBeforeReturnMinutes)
    }
}
