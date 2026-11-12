import Foundation

/// Єдина точка доступу до даних для застосунку й віджетів: мережа + кеш.
actor ScheduleRepository {
    private let service: any ScheduleSourcing
    private let cache: ScheduleCaching
    private let now: @Sendable () -> Date
    private let onUpdate: (@Sendable () -> Void)?
    private let status: RefreshStatusStore?

    init(service: any ScheduleSourcing, cache: ScheduleCaching,
         now: @escaping @Sendable () -> Date = { Date() },
         status: RefreshStatusStore? = nil,
         onUpdate: (@Sendable () -> Void)? = nil) {
        self.service = service
        self.cache = cache
        self.now = now
        self.status = status
        self.onUpdate = onUpdate
    }

    func cachedSnapshot() -> ScheduleSnapshot? { cache.load() }

    /// При будь-якій помилці кеш залишається недоторканим.
    /// Результат (успіх чи помилка) записується в `status`, щоб віджети могли показати, що оновити не вдалося.
    func refresh() async throws -> ScheduleSnapshot {
        do {
            let snapshot = try await service.fetchLatest(previous: cache.load())
            do {
                try cache.save(snapshot)
            } catch {
                throw ScheduleError.invalidData("Не вдалося зберегти дані на пристрої.")
            }
            status?.lastFailure = nil
            onUpdate?()
            return snapshot
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            let message = (error as? ScheduleError)?.message ?? ScheduleError.serverUnavailable(status: nil).message
            status?.lastFailure = RefreshFailure(at: now(), message: message)
            throw error
        }
    }

    /// Для віджетів: оновлює дані, лише якщо кеш старіший за `maxAge`; при невдачі повертає кеш.
    /// Дані для таймлайна віджета (NOL-42): у ручному режимі лише кеш, без мережі.
    func widgetSnapshot(allowsSelfRefresh: Bool, maxAge: TimeInterval = 15 * 60) async -> ScheduleSnapshot? {
        allowsSelfRefresh ? await refreshIfNeeded(maxAge: maxAge) : cache.load()
    }

    func refreshIfNeeded(maxAge: TimeInterval) async -> ScheduleSnapshot? {
        let cached = cache.load()
        if let cached, now().timeIntervalSince(cached.fetchedAt) < maxAge { return cached }
        return (try? await refresh()) ?? cached
    }
}

extension ScheduleRepository {
    /// Сайт Черкасиобленерго (як у v1). Віджети й застосунок для черкаських місць із джерелом «сайт».
    static func live(onUpdate: (@Sendable () -> Void)? = nil) -> ScheduleRepository {
        live(for: .cherkasySite, onUpdate: onUpdate)
    }

    /// Репозиторій для конкретного джерела й області: окремий кеш і окремий статус помилки.
    static func live(for key: ScheduleSourceKey, onUpdate: (@Sendable () -> Void)? = nil) -> ScheduleRepository {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 40
        config.waitsForConnectivity = false
        let fetcher = URLSessionHTMLFetcher(session: URLSession(configuration: config))
        let service: any ScheduleSourcing
        switch key.source {
        case .oblenergoSite:
            service = ScheduleService(fetcher: fetcher, newsListURL: AppConfig.newsListURL)
        case .outageDataAPI:
            service = OutageDataService(fetcher: fetcher, region: key.region)
        }
        return ScheduleRepository(service: service, cache: FileScheduleCache.appGroup(for: key),
                                  status: RefreshStatusStore.shared(for: key), onUpdate: onUpdate)
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
