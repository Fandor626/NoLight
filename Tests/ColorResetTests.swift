import XCTest

final class ColorResetTests: XCTestCase {
    func testResetRestoresDefaultsAndRemovesOverride() {
        let defaults = UserDefaults(suiteName: "ColorResetTests-\(UUID().uuidString)")!
        let store = ColorThemeStore(defaults: defaults)
        let settings = ColorSettings(store: store, readsLive: false)
        settings.theme = ColorPreset.highContrast.theme
        XCTAssertNotNil(defaults.data(forKey: ColorThemeStore.key))
        settings.reset()
        XCTAssertEqual(settings.theme, .default)
        XCTAssertTrue(settings.theme.isDefault)
        XCTAssertNil(defaults.data(forKey: ColorThemeStore.key), "Перевизначення видалено")
        XCTAssertEqual(store.theme, .default, "Віджети теж бачать стандартні")
    }

    func testSavingDefaultEqualsReset() {
        let defaults = UserDefaults(suiteName: "ColorResetTests-\(UUID().uuidString)")!
        let store = ColorThemeStore(defaults: defaults)
        store.save(ColorPreset.blueOrange.theme)
        store.save(.default)
        XCTAssertNil(defaults.data(forKey: ColorThemeStore.key))
    }
}
