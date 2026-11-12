import Foundation

/// Готові поєднання кольорів (NOL-33), зокрема для людей з порушеннями кольоросприйняття.
struct ColorPreset: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let note: String?
    let theme: ColorTheme

    static let standard = ColorPreset(id: "default", title: "Стандартні", note: "М’які зелений і червоний",
                                      theme: .default)

    static let highContrast = ColorPreset(
        id: "high-contrast", title: "Висока контрастність", note: "Насичені зелений і червоний",
        theme: ColorTheme(available: ThemedColor(light: RGBAColor(hex: "#1E7B34")!, dark: RGBAColor(hex: "#4ADE80")!),
                          outage: ThemedColor(light: RGBAColor(hex: "#C0161B")!, dark: RGBAColor(hex: "#FF6B6B")!)))

    /// Синій / помаранчевий: розрізняються при дейтеранопії та протанопії (червоно-зелений дальтонізм).
    static let blueOrange = ColorPreset(
        id: "blue-orange", title: "Синій / помаранчевий", note: "Для червоно-зеленого дальтонізму",
        theme: ColorTheme(available: ThemedColor(light: RGBAColor(hex: "#1F6FB5")!, dark: RGBAColor(hex: "#5AA9FF")!),
                          outage: ThemedColor(light: RGBAColor(hex: "#B85000")!, dark: RGBAColor(hex: "#FF9F43")!)))

    /// Бірюзовий / малиновий: розрізняються при тританопії (синьо-жовтий дальтонізм).
    static let tealMagenta = ColorPreset(
        id: "teal-magenta", title: "Бірюзовий / малиновий", note: "Для синьо-жовтого дальтонізму",
        theme: ColorTheme(available: ThemedColor(light: RGBAColor(hex: "#00797A")!, dark: RGBAColor(hex: "#3FD0C9")!),
                          outage: ThemedColor(light: RGBAColor(hex: "#C2185B")!, dark: RGBAColor(hex: "#FF6E9C")!)))

    static let all: [ColorPreset] = [.standard, .highContrast, .blueOrange, .tealMagenta]

    /// Пресет, що точно збігається з поточною темою (nil — свої кольори).
    static func matching(_ theme: ColorTheme) -> ColorPreset? { all.first { $0.theme == theme } }
}

/// Контраст за WCAG 2.x (1...21).
enum ColorContrast {
    /// Фон карток: білий у світлій темі, secondarySystemGroupedBackground (#1C1C1E) у темній.
    static let lightBackground = RGBAColor(hex: "#FFFFFF")!
    static let darkBackground = RGBAColor(hex: "#1C1C1E")!
    /// Мінімум для графічних елементів і великого тексту.
    static let minimumRatio = 3.0

    static func luminance(_ c: RGBAColor) -> Double {
        func lin(_ v: Double) -> Double { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(c.red) + 0.7152 * lin(c.green) + 0.0722 * lin(c.blue)
    }

    static func ratio(_ a: RGBAColor, _ b: RGBAColor) -> Double {
        let (x, y) = (luminance(a), luminance(b))
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }

    /// Обидва кольори теми читаються на фоні і світлої, і темної теми.
    static func isReadable(_ theme: ColorTheme) -> Bool {
        [theme.available, theme.outage].allSatisfy {
            ratio($0.light, lightBackground) >= minimumRatio && ratio($0.dark, darkBackground) >= minimumRatio
        }
    }
}
