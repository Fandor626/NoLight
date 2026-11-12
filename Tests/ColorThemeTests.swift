import XCTest

final class ColorThemeTests: XCTestCase {
    private func makeStore() -> ColorThemeStore {
        ColorThemeStore(defaults: UserDefaults(suiteName: "ColorThemeTests-\(UUID().uuidString)")!)
    }

    func testHexRoundTrip() throws {
        let c = try XCTUnwrap(RGBAColor(hex: "#4CAB75"))
        XCTAssertEqual(c.hex, "#4CAB75")
        XCTAssertEqual(RGBAColor(hex: "ff000080")?.hex, "#FF000080")
        XCTAssertNil(RGBAColor(hex: "#12"))
        XCTAssertNil(RGBAColor(hex: "zzzzzz"))
    }

    func testValuesAreClamped() {
        let c = RGBAColor(red: 2, green: -1, blue: 0.5)
        XCTAssertEqual(c.red, 1)
        XCTAssertEqual(c.green, 0)
    }

    func testDefaultWhenNothingStored() {
        XCTAssertEqual(makeStore().theme, .default)
    }

    func testBothThemesAreStored() {
        let store = makeStore()
        var theme = ColorTheme.default
        theme.available.light = RGBAColor(hex: "#0000FF")!
        theme.available.dark = RGBAColor(hex: "#00FFFF")!
        store.save(theme)
        XCTAssertEqual(store.theme.available.light.hex, "#0000FF")
        XCTAssertEqual(store.theme.available.dark.hex, "#00FFFF")
        XCTAssertEqual(store.theme.outage, ColorTheme.default.outage)
        XCTAssertEqual(store.theme.available.color(isDark: true).hex, "#00FFFF")
    }

    func testCorruptedDataFallsBackToDefault() {
        let defaults = UserDefaults(suiteName: "ColorThemeTests-\(UUID().uuidString)")!
        defaults.set(Data("{\"available\":1}".utf8), forKey: ColorThemeStore.key)
        XCTAssertEqual(ColorThemeStore(defaults: defaults).theme, .default)
    }

    func testSettingsAreVisibleImmediatelyAndStoredForWidgets() {
        let store = makeStore()
        let settings = ColorSettings(store: store, readsLive: false)
        var theme = ColorTheme.default
        theme.outage.light = RGBAColor(hex: "#FF8800")!
        settings.theme = theme
        XCTAssertEqual(settings.theme.outage.light.hex, "#FF8800")
        XCTAssertEqual(store.theme.outage.light.hex, "#FF8800", "Збережено в App Group для віджетів")
    }

    func testWidgetReadsLatestStoredTheme() {
        let store = makeStore()
        let widget = ColorSettings(store: store, readsLive: true)
        var theme = ColorTheme.default
        theme.available.dark = RGBAColor(hex: "#112233")!
        store.save(theme)  // зміна із застосунку
        XCTAssertEqual(widget.theme.available.dark.hex, "#112233")
    }
}
