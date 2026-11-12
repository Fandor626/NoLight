import XCTest

final class SourceChoiceTests: XCTestCase {
    func testCherkasyCanChooseSiteOrApi() {
        let p = Place(name: "Дім", subgroup: Subgroup(queue: 3, sub: 2)!)
        XCTAssertEqual(p.availableSources, [.oblenergoSite, .outageDataAPI])
        XCTAssertEqual(p.source, .oblenergoSite)                      // за замовчуванням — сайт
        XCTAssertEqual(PlaceSource.oblenergoSite.shortTitle, "Сайт обленерго")
        XCTAssertEqual(PlaceSource.outageDataAPI.shortTitle, "API")
    }

    func testSwitchingCherkasyToApiChangesSourceKey() {
        var p = Place(name: "Дім", subgroup: Subgroup(queue: 3, sub: 2)!)
        p.source = .outageDataAPI
        XCTAssertEqual(p.sourceKey, ScheduleSourceKey(source: .outageDataAPI, region: .cherkasy))
        XCTAssertNotEqual(p.sourceKey, .cherkasySite)
    }

    func testOtherRegionsHaveNoChoiceAndUseApi() {
        let p = Place(name: "Батьки", region: .poltava, subgroup: Subgroup(queue: 1, sub: 1)!, source: .outageDataAPI)
        XCTAssertEqual(p.availableSources, [.outageDataAPI])
        XCTAssertEqual(p.sourceKey.source, .outageDataAPI)
    }

    func testSourcePersistsWithPlace() {
        let suite = "nl-src-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var p = Place(name: "Дім", subgroup: Subgroup(queue: 3, sub: 2)!)
        p.source = .outageDataAPI
        PlaceStore(defaults: defaults).places = [p]
        XCTAssertEqual(PlaceStore(defaults: defaults).places.first?.source, .outageDataAPI)
    }
}
