import Foundation
import Observation
import WidgetKit

/// Стан застосунку годинника (NOL-46): місця з iPhone, вибране місце й графік його джерела.
@MainActor
@Observable
final class WatchState {
    private(set) var places: [Place] = PlaceStore.shared.places
    private(set) var placeID: UUID? = WatchPlaceStore.resolve(chosen: WatchPlaceStore.shared.placeID,
                                                              places: PlaceStore.shared.places)
    private(set) var snapshots: [ScheduleSourceKey: ScheduleSnapshot] = [:]
    private(set) var isRefreshing = false
    private(set) var lastError: ScheduleError?

    var place: Place? { places.first { $0.id == placeID } }

    func snapshot(for place: Place) -> ScheduleSnapshot? { snapshots[place.sourceKey] }

    /// Після нових даних з iPhone.
    func reloadFromStores() {
        places = PlaceStore.shared.places
        placeID = WatchPlaceStore.resolve(chosen: WatchPlaceStore.shared.placeID, places: places)
        WidgetCenter.shared.reloadAllTimelines()
        Task { await refresh() }
    }

    func choose(_ place: Place) {
        WatchPlaceStore.shared.placeID = place.id
        placeID = place.id
        WidgetCenter.shared.reloadAllTimelines()
        Task { await refresh() }
    }

    /// Годинник сам ходить у мережу (iPhone може бути далеко); кеш — у App Group годинника для віджета.
    func refresh() async {
        guard let place, !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let repo = ScheduleRepository.live(for: place.sourceKey, onUpdate: { WidgetCenter.shared.reloadAllTimelines() })
        if snapshots[place.sourceKey] == nil { snapshots[place.sourceKey] = await repo.cachedSnapshot() }
        do {
            snapshots[place.sourceKey] = try await repo.refresh()
            lastError = nil
        } catch {
            lastError = (error as? ScheduleError) ?? .serverUnavailable(status: nil)
            snapshots[place.sourceKey] = await repo.cachedSnapshot()
        }
    }
}
