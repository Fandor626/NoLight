import XCTest

final class TravelPreviewTests: XCTestCase {
    func testTransientPlaceIsNotSaved() throws {
        let store = PlaceStore(defaults: UserDefaults(suiteName: "TravelPreviewTests-\(UUID().uuidString)")!)
        let before = store.places
        var sel = TravelSelection()
        sel.region = .lviv; sel.queue = 2; sel.sub = 1
        let place = try XCTUnwrap(sel.transientPlace)
        XCTAssertEqual(place.subgroup.id, "2.1")
        XCTAssertEqual(place.region, .lviv)
        XCTAssertEqual(place.id, TravelSelection.transientID)
        XCTAssertEqual(store.places, before, "Перегляд не змінює збережені місця")
    }

    func testSourceKeyFollowsRegionDefault() {
        var sel = TravelSelection()
        XCTAssertEqual(sel.sourceKey, ScheduleSourceKey(source: Region.cherkasy.defaultSource, region: .cherkasy))
        sel.region = .kharkiv
        XCTAssertEqual(sel.sourceKey, ScheduleSourceKey(source: .outageDataAPI, region: .kharkiv))
        XCTAssertEqual(sel.transientPlace?.sourceKey, sel.sourceKey)
    }

    func testSaveAsPlaceKeepsParameters() throws {
        var sel = TravelSelection()
        sel.region = .poltava; sel.queue = 5; sel.sub = 2
        XCTAssertEqual(sel.suggestedName, "Полтавська обл., 5.2")
        let place = try XCTUnwrap(sel.makePlace(name: "  Дача  "))
        XCTAssertEqual(place.name, "Дача")
        XCTAssertEqual(place.region, .poltava)
        XCTAssertEqual(place.subgroup.id, "5.2")
        XCTAssertEqual(place.source, Region.poltava.defaultSource)
        XCTAssertNotEqual(place.id, TravelSelection.transientID)
    }

    func testSaveAsPlaceRejectsBadName() {
        let sel = TravelSelection()
        XCTAssertNil(sel.makePlace(name: "   "))
        XCTAssertNil(sel.makePlace(name: String(repeating: "a", count: Place.maxNameLength + 1)))
    }

    func testInvalidSubgroupHasNoPreview() {
        var sel = TravelSelection()
        sel.queue = 9
        XCTAssertNil(sel.transientPlace)
        XCTAssertNil(sel.makePlace(name: "X"))
    }

    func testPreviewUsesSameScheduleAsPlace() {
        let now = Fixtures.kyiv(2026, 11, 9, 10, 0)
        let snap = Fixtures.snapshot(posts: ["2026-11-09": ["1.1": [Fixtures.r(540, 720)]]], fetchedAt: now)
        let place = TravelSelection().transientPlace!
        let p = SubgroupPresentation(snapshot: snap, subgroup: place.subgroup, now: now)
        XCTAssertEqual(p.status.state, .outage)
    }

    func testDurationFormat() {
        XCTAssertEqual(TravelFormat.duration(150), "2 год 30 хв")
        XCTAssertEqual(TravelFormat.duration(30), "30 хв")
    }
}
