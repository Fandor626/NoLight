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

    func movePlaces(from source: IndexSet, to destination: Int) {
        places.move(fromOffsets: source, toOffset: destination)
        save()
    }

    private func save() {
        placeStore.places = places
        WidgetCenter.shared.reloadAllTimelines()
    }
}
