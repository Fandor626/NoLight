import Foundation
import Observation
import SwiftUI
import WidgetKit

@MainActor
@Observable
final class AppState {
    /// Збережені місця в порядку показу.
    private(set) var places: [Place]
    private(set) var snapshot: ScheduleSnapshot?
    private(set) var isRefreshing = false
    private(set) var lastError: ScheduleError?
    /// Місце, яке треба відкрити (посилання з віджета). Скидається після відкриття.
    var openedPlaceID: UUID?

    @ObservationIgnored private let repository: ScheduleRepository
    @ObservationIgnored private let placeStore: PlaceStore

    /// `settings` — сховище v1 (`selectedSubgroups.v1`); читається лише для одноразової міграції.
    init(repository: ScheduleRepository, settings: SettingsStore, placeStore: PlaceStore) {
        self.repository = repository
        self.placeStore = placeStore
        placeStore.migrateFromV1IfNeeded(v1Subgroups: settings.selectedSubgroups)
        self.places = placeStore.places
    }

    static func live() -> AppState {
        let repository = ScheduleRepository.live(onUpdate: { WidgetCenter.shared.reloadAllTimelines() })
        return AppState(repository: repository, settings: .shared, placeStore: .shared)
    }

    /// Спочатку миттєво показуємо кеш, потім оновлюємо з мережі.
    func start() async {
        snapshot = await repository.cachedSnapshot()
        await refresh()
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            snapshot = try await repository.refresh()
            lastError = nil
        } catch is CancellationError {
        } catch let error as ScheduleError {
            lastError = error
            snapshot = await repository.cachedSnapshot()
        } catch {
            lastError = .serverUnavailable(status: nil)
            snapshot = await repository.cachedSnapshot()
        }
    }

    func addPlace(_ place: Place) {
        places.append(place)
        save()
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
