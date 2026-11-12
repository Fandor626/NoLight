import Foundation
import Observation

/// Колір у sRGB (0...1), зберігається як «#RRGGBB» / «#RRGGBBAA» (NOL-32).
struct RGBAColor: Codable, Hashable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double = 1

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        func clamp(_ v: Double) -> Double { min(1, max(0, v)) }
        self.red = clamp(red); self.green = clamp(green); self.blue = clamp(blue); self.alpha = clamp(alpha)
    }

    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8, let v = UInt64(s, radix: 16) else { return nil }
        let rgba = s.count == 6 ? (v << 8) | 0xFF : v
        self.init(red: Double((rgba >> 24) & 0xFF) / 255, green: Double((rgba >> 16) & 0xFF) / 255,
                  blue: Double((rgba >> 8) & 0xFF) / 255, alpha: Double(rgba & 0xFF) / 255)
    }

    var hex: String {
        func b(_ v: Double) -> Int { Int((v * 255).rounded()) }
        return alpha >= 1
            ? String(format: "#%02X%02X%02X", b(red), b(green), b(blue))
            : String(format: "#%02X%02X%02X%02X", b(red), b(green), b(blue), b(alpha))
    }

    // Зберігаємо компактно як рядок.
    init(from decoder: Decoder) throws {
        let s = try decoder.singleValueContainer().decode(String.self)
        guard let c = RGBAColor(hex: s) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad color \(s)"))
        }
        self = c
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(hex)
    }
}

/// Колір стану для світлої й темної теми.
struct ThemedColor: Codable, Hashable, Sendable {
    var light: RGBAColor
    var dark: RGBAColor

    func color(isDark: Bool) -> RGBAColor { isDark ? dark : light }
}

/// Кольори «Світло є» і «Відключення». «Невідомо» лишається системним сірим.
struct ColorTheme: Codable, Hashable, Sendable {
    var available: ThemedColor
    var outage: ThemedColor

    /// Поточна приглушена палітра (як до NOL-32).
    static let `default` = ColorTheme(
        available: ThemedColor(light: RGBAColor(red: 0.30, green: 0.67, blue: 0.46),
                               dark: RGBAColor(red: 0.34, green: 0.66, blue: 0.48)),
        outage: ThemedColor(light: RGBAColor(red: 0.83, green: 0.40, blue: 0.38),
                            dark: RGBAColor(red: 0.78, green: 0.42, blue: 0.40)))

    var isDefault: Bool { self == .default }
}

/// Збережена тема в App Group: застосунок і віджети читають одне й те саме.
final class ColorThemeStore: @unchecked Sendable {
    private let defaults: UserDefaults
    static let key = "colorTheme.v1"

    init(defaults: UserDefaults) { self.defaults = defaults }

    static let shared = ColorThemeStore(defaults: UserDefaults(suiteName: AppConfig.appGroupID) ?? .standard)

    /// Нічого не збережено або дані пошкоджено → стандартні кольори.
    var theme: ColorTheme {
        guard let data = defaults.data(forKey: Self.key),
              let theme = try? JSONDecoder().decode(ColorTheme.self, from: data) else { return .default }
        return theme
    }

    func save(_ theme: ColorTheme) {
        if theme.isDefault { reset(); return }
        if let data = try? JSONEncoder().encode(theme) { defaults.set(data, forKey: Self.key) }
    }

    func reset() { defaults.removeObject(forKey: Self.key) }
}

/// Поточні кольори для UI. У застосунку — спостережуване значення (зміни видно одразу);
/// у віджеті читаються зі сховища при кожному рендері, бо процес віджета живе довго.
@Observable
final class ColorSettings: @unchecked Sendable {
    static let shared = ColorSettings(store: .shared)

    @ObservationIgnored private let store: ColorThemeStore
    @ObservationIgnored private let readsLive: Bool
    private var stored: ColorTheme

    init(store: ColorThemeStore, readsLive: Bool = Bundle.main.bundleURL.pathExtension == "appex") {
        self.store = store
        self.readsLive = readsLive
        self.stored = store.theme
    }

    var theme: ColorTheme {
        get { readsLive ? store.theme : stored }
        set {
            stored = newValue
            store.save(newValue)
        }
    }
}
