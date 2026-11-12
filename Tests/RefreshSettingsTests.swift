import XCTest

final class RefreshSettingsTests: XCTestCase {
    private var suite = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suite = "nl-refresh-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testDefaultsAreAutomaticEvery30Minutes() {
        let store = RefreshSettingsStore(defaults: defaults)
        XCTAssertEqual(store.mode, .automatic)
        XCTAssertEqual(store.interval, .min30)
    }

    func testPresetsAndMinimum() {
        XCTAssertEqual(RefreshInterval.allCases.map(\.rawValue), [15, 30, 60, 180, 360])
        XCTAssertEqual(RefreshInterval.allCases.map(\.title), ["15 хв", "30 хв", "1 год", "3 год", "6 год"])
        XCTAssertEqual(RefreshInterval.allCases.map(\.rawValue).min(), RefreshInterval.minimum.rawValue)
        XCTAssertEqual(RefreshInterval.minimum.seconds, 15 * 60)
    }

    func testSettingsPersist() {
        let store = RefreshSettingsStore(defaults: defaults)
        store.mode = .manual
        store.interval = .hour3
        let reloaded = RefreshSettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.mode, .manual)
        XCTAssertEqual(reloaded.interval, .hour3)
    }

    func testInvalidStoredIntervalFallsBackToDefault() {
        defaults.set(5, forKey: RefreshSettingsStore.intervalKey)   // менше за мінімум
        XCTAssertEqual(RefreshSettingsStore(defaults: defaults).interval, .min30)
    }

    func testManualModeSchedulesNoBackgroundRefresh() {
        let store = RefreshSettingsStore(defaults: defaults)
        store.mode = .manual
        XCTAssertNil(store.nextBackgroundRefresh(after: Date()))
    }

    func testAutomaticModeUsesChosenInterval() {
        let store = RefreshSettingsStore(defaults: defaults)
        store.interval = .hour1
        let now = Date()
        XCTAssertEqual(store.nextBackgroundRefresh(after: now), now.addingTimeInterval(3600))
    }
}
