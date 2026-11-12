import XCTest

final class PlaceCardsTests: XCTestCase {
    private func places(_ n: Int) -> [Place] {
        (0..<n).map { Place(name: "Місце \($0)", subgroup: Subgroup(queue: $0 % 6 + 1, sub: 1)!) }
    }

    func testMediumShowsFirstTwoInAppOrder() {
        let all = places(3)
        let v = PlacesListLayout.visible(all, capacity: PlacesListLayout.mediumCapacity)
        XCTAssertEqual(v.shown, Array(all.prefix(2)))
        XCTAssertEqual(v.overflow, 1)
    }

    func testLargeShowsFirstFour() {
        let v = PlacesListLayout.visible(places(4), capacity: PlacesListLayout.largeCapacity)
        XCTAssertEqual(v.shown.count, 4)
        XCTAssertEqual(v.overflow, 0)
        XCTAssertNil(PlacesListLayout.overflowText(v.overflow))
    }

    func testNoPlaces() {
        let v = PlacesListLayout.visible([], capacity: 2)
        XCTAssertTrue(v.shown.isEmpty)
        XCTAssertEqual(v.overflow, 0)
    }

    func testOverflowTextUkrainianPlurals() {
        XCTAssertEqual(PlacesListLayout.overflowText(1), "+1 місце")
        XCTAssertEqual(PlacesListLayout.overflowText(2), "+2 місця")
        XCTAssertEqual(PlacesListLayout.overflowText(4), "+4 місця")
        XCTAssertEqual(PlacesListLayout.overflowText(5), "+5 місць")
        XCTAssertEqual(PlacesListLayout.overflowText(11), "+11 місць")
        XCTAssertEqual(PlacesListLayout.overflowText(12), "+12 місць")
        XCTAssertEqual(PlacesListLayout.overflowText(21), "+21 місце")
        XCTAssertEqual(PlacesListLayout.overflowText(22), "+22 місця")
    }

    func testDeepLinkRoundTrip() {
        let id = UUID()
        let url = DeepLink.place(id)
        XCTAssertEqual(url.absoluteString, "nolight://place/\(id.uuidString)")
        XCTAssertEqual(DeepLink.placeID(from: url), id)
    }

    func testDeepLinkRejectsOtherURLs() {
        XCTAssertNil(DeepLink.placeID(from: DeepLink.home))
        XCTAssertNil(DeepLink.placeID(from: URL(string: "https://place/\(UUID().uuidString)")!))
        XCTAssertNil(DeepLink.placeID(from: URL(string: "nolight://place/not-a-uuid")!))
    }

    /// AC2/AC8: застосунок і віджет беруть тексти з однієї `SubgroupPresentation`; без даних — ніколи не «Світло є».
    func testCardTextsComeFromOnePresentationAndNeverClaimPowerWithoutData() {
        let p = SubgroupPresentation(snapshot: nil, subgroup: Subgroup(queue: 1, sub: 1)!, now: Date())
        XCTAssertEqual(p.status.state, .unknown)
        XCTAssertNotEqual(p.headline, "Світло є")
    }
}
