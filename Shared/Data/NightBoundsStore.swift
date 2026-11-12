import Foundation

/// Межі ночі для статистики в App Group (NOL-27).
final class NightBoundsStore: @unchecked Sendable {
    private let defaults: UserDefaults
    static let startKey = "nightStartMinute"
    static let endKey = "nightEndMinute"

    init(defaults: UserDefaults) { self.defaults = defaults }

    static let shared = NightBoundsStore(defaults: UserDefaults(suiteName: AppConfig.appGroupID) ?? .standard)

    /// Збережені межі; нічого не збережено або значення некоректні → 00:00–06:00.
    var bounds: NightBounds {
        guard defaults.object(forKey: Self.startKey) != nil, defaults.object(forKey: Self.endKey) != nil else {
            return .default
        }
        let b = NightBounds(startMinute: defaults.integer(forKey: Self.startKey),
                            endMinute: defaults.integer(forKey: Self.endKey))
        return b.isValid ? b : .default
    }

    /// Зберігає лише коректні межі. Повертає false, якщо початок дорівнює кінцю (нічого не змінено).
    @discardableResult
    func save(_ bounds: NightBounds) -> Bool {
        guard bounds.isValid else { return false }
        defaults.set(bounds.startMinute, forKey: Self.startKey)
        defaults.set(bounds.endMinute, forKey: Self.endKey)
        return true
    }

    func reset() {
        defaults.removeObject(forKey: Self.startKey)
        defaults.removeObject(forKey: Self.endKey)
    }
}
