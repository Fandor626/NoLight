import XCTest

final class ColorPresetsTests: XCTestCase {
    func testSeveralPresetsIncludingColorBlindOnes() {
        XCTAssertGreaterThanOrEqual(ColorPreset.all.count, 3)
        XCTAssertEqual(Set(ColorPreset.all.map(\.id)).count, ColorPreset.all.count)
        XCTAssertTrue(ColorPreset.all.contains(.blueOrange))
        XCTAssertTrue(ColorPreset.all.contains(.tealMagenta))
        XCTAssertEqual(ColorPreset.standard.theme, .default)
    }

    func testNonDefaultPresetsAreReadableInLightAndDark() {
        for preset in ColorPreset.all where preset != .standard {
            XCTAssertTrue(ColorContrast.isReadable(preset.theme), preset.title)
        }
    }

    func testStatesDifferInEveryPreset() {
        for preset in ColorPreset.all {
            XCTAssertNotEqual(preset.theme.available.light, preset.theme.outage.light, preset.title)
            XCTAssertNotEqual(preset.theme.available.dark, preset.theme.outage.dark, preset.title)
        }
    }

    func testContrastFormula() {
        let white = ColorContrast.lightBackground, black = RGBAColor(hex: "#000000")!
        XCTAssertEqual(ColorContrast.ratio(white, black), 21, accuracy: 0.01)
        XCTAssertEqual(ColorContrast.ratio(white, white), 1, accuracy: 0.001)
    }

    func testChoosingPresetAppliesAndIsStored() {
        let store = ColorThemeStore(defaults: UserDefaults(suiteName: "ColorPresetsTests-\(UUID().uuidString)")!)
        let settings = ColorSettings(store: store, readsLive: false)
        settings.theme = ColorPreset.blueOrange.theme
        XCTAssertEqual(ColorPreset.matching(settings.theme), .blueOrange)
        XCTAssertEqual(store.theme, ColorPreset.blueOrange.theme, "Віджети бачать пресет")
        var custom = settings.theme
        custom.outage.dark = RGBAColor(hex: "#123456")!
        XCTAssertNil(ColorPreset.matching(custom))
    }
}
