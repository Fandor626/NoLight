import XCTest

final class WidgetPlaceResolverTests: XCTestCase {
    private let home = Place(name: "Дім", subgroup: Subgroup(queue: 3, sub: 2)!)
    private let work = Place(name: "Робота", subgroup: Subgroup(queue: 4, sub: 2)!)

    func testSelectedPlaceIsShownWithItsName() {
        let r = WidgetPlaceResolver.resolve(placeID: work.id, legacySubgroup: Subgroup(queue: 1, sub: 1)!,
                                            places: [home, work])
        XCTAssertEqual(r, .place(work))
        XCTAssertEqual(r.title, "Робота")
        XCTAssertEqual(r.subgroup, work.subgroup)
    }

    func testRenamedPlaceUsesCurrentName() {
        var renamed = work
        renamed.name = "Офіс"
        let r = WidgetPlaceResolver.resolve(placeID: work.id, legacySubgroup: Subgroup(queue: 1, sub: 1)!,
                                            places: [home, renamed])
        XCTAssertEqual(r.title, "Офіс")
    }

    func testDeletedPlaceAsksToChooseAnother() {
        let r = WidgetPlaceResolver.resolve(placeID: UUID(), legacySubgroup: Subgroup(queue: 1, sub: 1)!,
                                            places: [home])
        XCTAssertEqual(r, .deleted)
        XCTAssertNil(r.subgroup)
    }

    func testV1WidgetResolvesToPlaceWithSameSubgroup() {
        let r = WidgetPlaceResolver.resolve(placeID: nil, legacySubgroup: Subgroup(queue: 3, sub: 2)!,
                                            places: [work, home])
        XCTAssertEqual(r, .place(home))
        XCTAssertEqual(r.title, "Дім")
    }

    func testV1WidgetWithoutMatchingPlaceKeepsShowingSubgroup() {
        let sg = Subgroup(queue: 6, sub: 1)!
        let r = WidgetPlaceResolver.resolve(placeID: nil, legacySubgroup: sg, places: [home])
        XCTAssertEqual(r, .legacy(sg))
        XCTAssertEqual(r.title, "Підчерга 6.1")
        XCTAssertEqual(r.subgroup, sg)
    }
}
