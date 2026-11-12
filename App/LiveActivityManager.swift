import ActivityKit
import Foundation

/// Запуск, оновлення й завершення Live Activity місць (NOL-39). Пушів немає:
/// відлік іде сам (`Text(timerInterval:)`), а вміст оновлюється, коли застосунок оновлює дані.
@MainActor
enum LiveActivityManager {
    static var isAvailable: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    static func activity(for placeID: UUID) -> Activity<PlaceActivityAttributes>? {
        Activity<PlaceActivityAttributes>.activities.first {
            $0.attributes.placeID == placeID && $0.activityState == .active
        }
    }

    static func isRunning(for placeID: UUID) -> Bool { activity(for: placeID) != nil }

    /// Запускає відлік для місця (попередній для цього місця завершується).
    @discardableResult
    static func start(place: Place, snapshot: ScheduleSnapshot?, now: Date = .now) async -> Bool {
        await stop(placeID: place.id)
        let p = SubgroupPresentation(snapshot: snapshot, subgroup: place.subgroup, now: now)
        let content = PlaceActivityPlanner.content(presentation: p, startedAt: now)
        let attributes = PlaceActivityAttributes(placeID: place.id, placeName: place.name, subgroupID: place.subgroup.id)
        do {
            _ = try Activity.request(attributes: attributes,
                                     content: .init(state: content, staleDate: PlaceActivityPlanner.staleDate(content)),
                                     pushType: nil)
            return true
        } catch {
            return false
        }
    }

    static func stop(placeID: UUID) async {
        for activity in Activity<PlaceActivityAttributes>.activities where activity.attributes.placeID == placeID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// Після оновлення даних або змін місць: новий стан/час зміни; видалене місце — завершити;
    /// минуло 8 год — завершити з підказкою запустити знову.
    static func update(places: [Place], snapshot: (Place) -> ScheduleSnapshot?, now: Date = .now) async {
        for activity in Activity<PlaceActivityAttributes>.activities where activity.activityState == .active {
            guard let place = places.first(where: { $0.id == activity.attributes.placeID }) else {
                await activity.end(nil, dismissalPolicy: .immediate)
                continue
            }
            let startedAt = activity.content.state.startedAt
            if PlaceActivityPlanner.isExpired(startedAt: startedAt, now: now) {
                await activity.end(activity.content, dismissalPolicy: .default)
                continue
            }
            let p = SubgroupPresentation(snapshot: snapshot(place), subgroup: place.subgroup, now: now)
            let content = PlaceActivityPlanner.content(presentation: p, startedAt: startedAt)
            await activity.update(.init(state: content, staleDate: PlaceActivityPlanner.staleDate(content)))
        }
    }

    /// Для фонового завдання: місця й кеш зі сховищ App Group.
    static func updateFromStores() async {
        let places = PlaceStore.shared.places
        var snapshots: [ScheduleSourceKey: ScheduleSnapshot] = [:]
        for key in ScheduleSourceKey.active(for: places) {
            snapshots[key] = FileScheduleCache.appGroup(for: key).load()
        }
        await update(places: places, snapshot: { snapshots[$0.sourceKey] })
    }
}
