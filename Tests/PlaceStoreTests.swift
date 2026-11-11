import XCTest

final class PlaceStoreTests: XCTestCase {
    private var suite = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suite = "nl-places-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private let sg32 = Subgroup(queue: 3, sub: 2)!
    private let sg11 = Subgroup(queue: 1, sub: 1)!
    private let sg52 = Subgroup(queue: 5, sub: 2)!

    func testSingleV1SubgroupBecomesHome() {
        let store = PlaceStore(defaults: defaults)
        XCTAssertTrue(store.migrateFromV1IfNeeded(v1Subgroups: [sg32]))
        XCTAssertEqual(store.places.count, 1)
        XCTAssertEqual(store.places[0].name, "Дім")
        XCTAssertEqual(store.places[0].subgroup, sg32)
        XCTAssertEqual(store.places[0].region, .cherkasy)
        XCTAssertEqual(store.places[0].source, .oblenergoSite)
    }

    func testSeveralV1SubgroupsAreAllKeptInOrder() {
        let store = PlaceStore(defaults: defaults)
        store.migrateFromV1IfNeeded(v1Subgroups: [sg32, sg11, sg52])
        XCTAssertEqual(store.places.map(\.subgroup), [sg32, sg11, sg52])
        XCTAssertEqual(store.places.map(\.name), ["Дім", "Підчерга 1.1", "Підчерга 5.2"])
        XCTAssertEqual(Set(store.places.map(\.id)).count, 3)
    }

    func testDuplicateV1SubgroupsAreMigratedOnce() {
        let places = PlaceMigration.places(fromV1: [sg11, sg11, sg32])
        XCTAssertEqual(places.map(\.subgroup), [sg11, sg32])
    }

    func testMigrationRunsOnlyOnce() {
        let store = PlaceStore(defaults: defaults)
        store.migrateFromV1IfNeeded(v1Subgroups: [sg32])
        XCTAssertFalse(store.migrateFromV1IfNeeded(v1Subgroups: [sg32, sg11]))
        XCTAssertEqual(PlaceStore(defaults: defaults).places.count, 1)
    }

    func testMigrationDoesNotRerunAfterUserDeletedAllPlaces() {
        let store = PlaceStore(defaults: defaults)
        store.migrateFromV1IfNeeded(v1Subgroups: [sg32])
        store.places = []
        XCTAssertFalse(store.migrateFromV1IfNeeded(v1Subgroups: [sg32]))
        XCTAssertTrue(store.places.isEmpty)
    }

    func testNoV1DataMeansNoPlacesButMigrationIsMarkedDone() {
        let store = PlaceStore(defaults: defaults)
        XCTAssertFalse(store.migrateFromV1IfNeeded(v1Subgroups: []))
        XCTAssertTrue(store.places.isEmpty)
        XCTAssertTrue(store.isMigrated)
    }

    func testMigrationKeepsV1SelectionUntouched() {
        let settings = SettingsStore(defaults: defaults)
        settings.selectedSubgroups = [sg32]
        PlaceStore(defaults: defaults).migrateFromV1IfNeeded(v1Subgroups: settings.selectedSubgroups)
        XCTAssertEqual(SettingsStore(defaults: defaults).selectedSubgroups, [sg32])
    }

    func testPlacesPersistAcrossInstances() {
        let place = Place(name: "Робота", subgroup: sg52)
        PlaceStore(defaults: defaults).places = [place]
        XCTAssertEqual(PlaceStore(defaults: defaults).places, [place])
    }

    func testCorruptedPlacesDataReadsAsEmpty() {
        defaults.set(Data("not json".utf8), forKey: PlaceStore.placesKey)
        XCTAssertEqual(PlaceStore(defaults: defaults).places, [])
    }

    func testPlaceCodableRoundTrip() throws {
        let place = Place(name: "Дім", subgroup: sg32)
        let data = try JSONEncoder().encode(place)
        XCTAssertEqual(try JSONDecoder().decode(Place.self, from: data), place)
    }
}
