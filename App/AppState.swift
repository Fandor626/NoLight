import Foundation
import Observation
import SwiftUI
import WidgetKit

@MainActor
@Observable
final class AppState {
    /// Збережені місця в порядку показу.
    private(set) var places: [Place]
    /// Дані кожного джерела й області, що використовуються місцями (NOL-15).
    private(set) var snapshots: [ScheduleSourceKey: ScheduleSnapshot] = [:]
    private(set) var errors: [ScheduleSourceKey: ScheduleError] = [:]
    private(set) var isRefreshing = false
    /// Історія змін графіка всіх місць (NOL-24).
    private(set) var changeHistory: [ScheduleChange] = ScheduleChangeHistoryStore.shared.changes
    /// Місце, яке треба відкрити (посилання з віджета). Скидається після відкриття.
    var openedPlaceID: UUID?

    @ObservationIgnored private let makeRepository: (ScheduleSourceKey) -> ScheduleRepository
    @ObservationIgnored private var repositories: [ScheduleSourceKey: ScheduleRepository] = [:]
    @ObservationIgnored private let placeStore: PlaceStore

    /// `settings` — сховище v1 (`selectedSubgroups.v1`); читається лише для одноразової міграції.
    init(makeRepository: @escaping (ScheduleSourceKey) -> ScheduleRepository,
         settings: SettingsStore, placeStore: PlaceStore) {
        self.makeRepository = makeRepository
        self.placeStore = placeStore
        placeStore.migrateFromV1IfNeeded(v1Subgroups: settings.selectedSubgroups)
        self.places = placeStore.places
    }

    static func live() -> AppState {
        AppState(makeRepository: { ScheduleRepository.live(for: $0, onUpdate: { WidgetCenter.shared.reloadAllTimelines() }) },
                 settings: .shared, placeStore: .shared)
    }

    /// Джерела, потрібні місцям. Без місць — сайт Черкас (як у v1).
    var activeKeys: [ScheduleSourceKey] { ScheduleSourceKey.active(for: places) }

    func snapshot(for place: Place) -> ScheduleSnapshot? { snapshots[place.sourceKey] }
    func error(for place: Place) -> ScheduleError? { errors[place.sourceKey] }

    /// Для загальних банерів і налаштувань: перше джерело зі списку місць.
    var snapshot: ScheduleSnapshot? { snapshots[activeKeys[0]] }
    /// Перша помилка серед джерел, що використовуються.
    var lastError: ScheduleError? { activeKeys.lazy.compactMap { self.errors[$0] }.first }

    private func repository(for key: ScheduleSourceKey) -> ScheduleRepository {
        if let repo = repositories[key] { return repo }
        let repo = makeRepository(key)
        repositories[key] = repo
        return repo
    }

    /// Спочатку миттєво показуємо кеш, потім оновлюємо з мережі.
    func start() async {
        for key in activeKeys where snapshots[key] == nil {
            snapshots[key] = await repository(for: key).cachedSnapshot()
        }
        await refresh()
    }

    /// Повертає відліки «завжди на екрані» (NOL-43); лише коли застосунок активний.
    func restoreLiveActivities() async {
        let snaps = snapshots
        await LiveActivityManager.restore(places: places, snapshot: { snaps[$0.sourceKey] })
    }

    /// Оновлює всі джерела, що використовують місця (паралельно). Помилка одного джерела не зачіпає інші.
    func refresh() async {
        await refresh(keys: activeKeys)
    }

    func refresh(keys: [ScheduleSourceKey]) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let repos = keys.map { ($0, repository(for: $0)) }
        let results = await withTaskGroup(of: (ScheduleSourceKey, Result<ScheduleSnapshot, ScheduleError>?, ScheduleSnapshot?).self) { group in
            for (key, repo) in repos {
                group.addTask {
                    do { return (key, .success(try await repo.refresh()), nil) }
                    catch is CancellationError { return (key, nil, nil) }
                    catch {
                        let mapped = (error as? ScheduleError) ?? .serverUnavailable(status: nil)
                        return (key, .failure(mapped), await repo.cachedSnapshot())
                    }
                }
            }
            var out: [(ScheduleSourceKey, Result<ScheduleSnapshot, ScheduleError>?, ScheduleSnapshot?)] = []
            for await r in group { out.append(r) }
            return out
        }
        for (key, result, cached) in results {
            switch result {
            case .success(let snapshot)?:
                snapshots[key] = snapshot
                errors[key] = nil
            case .failure(let error)?:
                errors[key] = error
                snapshots[key] = cached
            case nil:
                break
            }
        }
        // Зміни графіка (NOL-23) — до перепланування попереджень.
        let snaps = snapshots
        await ScheduleChangeNotifier.process(places: places, snapshot: { snaps[$0.sourceKey] })
        changeHistory = ScheduleChangeHistoryStore.shared.changes
        await replanNotifications()
    }

    // MARK: - Подорож (NOL-28): графік будь-якої області без створення місця

    private(set) var previewLoading: Set<ScheduleSourceKey> = []

    func snapshot(forKey key: ScheduleSourceKey) -> ScheduleSnapshot? { snapshots[key] }
    func error(forKey key: ScheduleSourceKey) -> ScheduleError? { errors[key] }

    /// Показує кеш одразу, потім оновлює лише це джерело. Місця не змінюються й не зберігаються.
    func loadPreview(_ key: ScheduleSourceKey) async {
        guard !previewLoading.contains(key) else { return }
        previewLoading.insert(key)
        defer { previewLoading.remove(key) }
        let repo = repository(for: key)
        if snapshots[key] == nil { snapshots[key] = await repo.cachedSnapshot() }
        do {
            snapshots[key] = try await repo.refresh()
            errors[key] = nil
        } catch is CancellationError {
        } catch {
            errors[key] = (error as? ScheduleError) ?? .serverUnavailable(status: nil)
            snapshots[key] = await repo.cachedSnapshot()
        }
    }

    func addPlace(_ place: Place) {
        let isNewSource = !activeKeys.contains(place.sourceKey) || snapshots[place.sourceKey] == nil
        places.append(place)
        save()
        // Нова область або джерело — одразу завантажуємо її графік.
        if isNewSource {
            Task {
                let key = place.sourceKey
                if snapshots[key] == nil { snapshots[key] = await repository(for: key).cachedSnapshot() }
                await refresh(keys: [key])
            }
        }
    }

    /// Єдина точка видалення місця. Заплановані сповіщення місця скасовуватимуться тут (NOL-21).
    func removePlace(_ place: Place) {
        places.removeAll { $0.id == place.id }
        save()
    }

    /// Повертає false, якщо назва порожня або задовга.
    @discardableResult
    func renamePlace(_ place: Place, to newName: String) -> Bool {
        guard let name = Place.normalizedName(newName),
              let index = places.firstIndex(where: { $0.id == place.id }) else { return false }
        places[index].name = name
        save()
        return true
    }

    /// Для «Порівняння джерел» (NOL-18): обидва джерела Черкас — кеш одразу, мережа паралельно.
    func loadComparison(forceRefresh: Bool = false) async {
        let keys = [ScheduleSourceKey.cherkasySite, ScheduleSourceKey(source: .outageDataAPI, region: .cherkasy)]
        for key in keys where snapshots[key] == nil {
            snapshots[key] = await repository(for: key).cachedSnapshot()
        }
        let needsRefresh = forceRefresh || keys.contains { key in
            guard let fetched = snapshots[key]?.fetchedAt else { return true }
            return Date().timeIntervalSince(fetched) > 15 * 60
        }
        if needsRefresh { await refresh(keys: keys) }
    }

    /// Змінює джерело місця (NOL-17) і одразу завантажує графік з нового джерела.
    func setSource(_ source: PlaceSource, for place: Place) {
        guard place.availableSources.contains(source),
              let index = places.firstIndex(where: { $0.id == place.id }),
              places[index].source != source else { return }
        places[index].source = source
        // Інше джерело — інший графік: не вважаємо це «зміною графіка» (NOL-23).
        var seen = ScheduleSeenStore.shared.seen
        seen[place.id.uuidString] = nil
        ScheduleSeenStore.shared.seen = seen
        save()
        let key = places[index].sourceKey
        Task {
            if snapshots[key] == nil { snapshots[key] = await repository(for: key).cachedSnapshot() }
            await refresh(keys: [key])
        }
    }

    func movePlaces(from source: IndexSet, to destination: Int) {
        places.move(fromOffsets: source, toOffset: destination)
        save()
    }

    private func save() {
        placeStore.places = places
        WidgetCenter.shared.reloadAllTimelines()
        WatchSync.shared.send(places: places)
        Task { await replanNotifications() }
    }

    /// Попередження перед відключенням (NOL-21): переплановуються після оновлення даних і будь-якої зміни місць.
    func replanNotifications() async {
        let snaps = snapshots
        await NotificationScheduler.replan(places: places, snapshot: { snaps[$0.sourceKey] })
        // Live Activity місць (NOL-39) — новий стан і час зміни.
        await LiveActivityManager.update(places: places, snapshot: { snaps[$0.sourceKey] })
    }

    /// Сповіщення про зміну графіка місця (NOL-23).
    func setNotifyScheduleChanges(_ on: Bool, for place: Place) {
        guard let index = places.firstIndex(where: { $0.id == place.id }) else { return }
        places[index].notifyScheduleChanges = on
        if on {
            Task {
                await NotificationScheduler.requestAuthorization()
                save()
            }
        } else {
            save()
        }
    }

    /// Вмикає (хвилини) або вимикає (nil) попередження перед поверненням світла (NOL-22).
    func setWarningBeforeReturn(_ minutes: Int?, for place: Place) {
        guard let index = places.firstIndex(where: { $0.id == place.id }) else { return }
        places[index].warnBeforeReturnMinutes = minutes
        if minutes != nil {
            Task {
                await NotificationScheduler.requestAuthorization()
                save()
            }
        } else {
            save()
        }
    }

    /// Вмикає (хвилини) або вимикає (nil) попередження перед відключенням для місця.
    func setWarningBeforeOutage(_ minutes: Int?, for place: Place) {
        guard let index = places.firstIndex(where: { $0.id == place.id }) else { return }
        places[index].warnBeforeOutageMinutes = minutes
        if minutes != nil {
            Task {
                await NotificationScheduler.requestAuthorization()
                save()
            }
        } else {
            save()
        }
    }
}
