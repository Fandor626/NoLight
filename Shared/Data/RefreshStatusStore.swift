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
    static let key = "lastRefreshFailure.v1"

    init(defaults: UserDefaults) { self.defaults = defaults }

    static let shared = RefreshStatusStore(defaults: UserDefaults(suiteName: AppConfig.appGroupID) ?? .standard)

    var lastFailure: RefreshFailure? {
        get {
            guard let data = defaults.data(forKey: Self.key) else { return nil }
            return try? JSONDecoder().decode(RefreshFailure.self, from: data)
        }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Self.key)
            } else {
                defaults.removeObject(forKey: Self.key)
            }
        }
    }
}
