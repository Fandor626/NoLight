import Foundation

/// Єдина точка доступу до даних для застосунку й віджетів: мережа + кеш.
actor ScheduleRepository {
    private let service: ScheduleService
    private let cache: ScheduleCaching
    private let now: @Sendable () -> Date
    private let onUpdate: (@Sendable () -> Void)?

    init(service: ScheduleService, cache: ScheduleCaching,
         now: @escaping @Sendable () -> Date = { Date() },
         onUpdate: (@Sendable () -> Void)? = nil) {
        self.service = service
        self.cache = cache
        self.now = now
        self.onUpdate = onUpdate
    }

    func cachedSnapshot() -> ScheduleSnapshot? { cache.load() }

    /// При будь-якій помилці кеш залишається недоторканим.
    func refresh() async throws -> ScheduleSnapshot {
        let snapshot = try await service.fetchLatest(previous: cache.load())
        do {
            try cache.save(snapshot)
        } catch {
            throw ScheduleError.invalidData("Не вдалося зберегти дані на пристрої.")
        }
        onUpdate?()
        return snapshot
    }

    /// Для віджетів: оновлює дані, лише якщо кеш старіший за `maxAge`; при невдачі повертає кеш.
    func refreshIfNeeded(maxAge: TimeInterval) async -> ScheduleSnapshot? {
        let cached = cache.load()
        if let cached, now().timeIntervalSince(cached.fetchedAt) < maxAge { return cached }
        return (try? await refresh()) ?? cached
    }
}

extension ScheduleRepository {
    static func live(onUpdate: (@Sendable () -> Void)? = nil) -> ScheduleRepository {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 40
        config.waitsForConnectivity = false
        let session = URLSession(configuration: config)
        let service = ScheduleService(fetcher: URLSessionHTMLFetcher(session: session),
                                      newsListURL: AppConfig.newsListURL)
        return ScheduleRepository(service: service, cache: FileScheduleCache.appGroup(), onUpdate: onUpdate)
    }
}

/// Локальні налаштування (обрані підчерги): UserDefaults в App Group.
final class SettingsStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "selectedSubgroups.v1"

    init(defaults: UserDefaults) { self.defaults = defaults }

    static let shared = SettingsStore(defaults: UserDefaults(suiteName: AppConfig.appGroupID) ?? .standard)

    var selectedSubgroups: [Subgroup] {
        get { (defaults.stringArray(forKey: key) ?? []).compactMap { Subgroup(id: $0) } }
        set { defaults.set(newValue.map { $0.id }, forKey: key) }
    }
}
