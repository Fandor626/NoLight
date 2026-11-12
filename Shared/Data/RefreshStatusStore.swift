import Foundation

/// Остання невдала спроба оновлення (спільна для застосунку й віджетів через App Group).
struct RefreshFailure: Codable, Equatable, Sendable {
    let at: Date
    let message: String

    /// Помилка актуальна, якщо сталася після останнього успішного оновлення.
    func isNewer(than fetchedAt: Date?) -> Bool {
        guard let fetchedAt else { return true }
        return at > fetchedAt
    }
}

final class RefreshStatusStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let storageKey: String
    static let key = "lastRefreshFailure.v1"

    init(defaults: UserDefaults, key: String = RefreshStatusStore.key) {
        self.defaults = defaults
        self.storageKey = key
    }

    private static var groupDefaults: UserDefaults { UserDefaults(suiteName: AppConfig.appGroupID) ?? .standard }

    /// Сайт Черкас (ключ v1).
    static let shared = RefreshStatusStore(defaults: groupDefaults)

    /// Окремий статус для кожного джерела й області.
    static func shared(for source: ScheduleSourceKey) -> RefreshStatusStore {
        source == .cherkasySite
            ? shared
            : RefreshStatusStore(defaults: groupDefaults,
                                 key: "lastRefreshFailure.\(source.source.rawValue).\(source.region.rawValue).v1")
    }

    var lastFailure: RefreshFailure? {
        get {
            guard let data = defaults.data(forKey: storageKey) else { return nil }
            return try? JSONDecoder().decode(RefreshFailure.self, from: data)
        }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: storageKey)
            } else {
                defaults.removeObject(forKey: storageKey)
            }
        }
    }
}
