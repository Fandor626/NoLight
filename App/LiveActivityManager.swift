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
        await end(placeID: place.id)
        let p = SubgroupPresentation(snapshot: snapshot, subgroup: place.subgroup, now: now)
        let content = PlaceActivityPlanner.content(presentation: p, startedAt: now)
        let attributes = PlaceActivityAttributes(placeID: place.id, placeName: place.name, subgroupID: place.subgroup.id)
        do {
            _ = try Activity.request(attributes: attributes,
                                     content: .init(state: content, staleDate: PlaceActivityPlanner.staleDate(content)),
                                     pushType: nil)
            // «Завжди на екрані» (NOL-43): відлік повертатиметься, доки його не зупинять у застосунку.
            LiveActivityKeepStore.shared.add(place.id)
            return true
        } catch {
            return false
        }
    }

    /// Зупинка з застосунку — єдиний спосіб прибрати відлік назавжди (NOL-43).
    static func stop(placeID: UUID) async {
        LiveActivityKeepStore.shared.remove(placeID)
        await end(placeID: placeID)
    }

    /// Чи має місце «завжди на екрані» (навіть якщо зараз відлік змахнули).
    static func isKept(_ placeID: UUID) -> Bool { LiveActivityKeepStore.shared.contains(placeID) }

    private static func end(placeID: UUID) async {
        for activity in Activity<PlaceActivityAttributes>.activities where activity.attributes.placeID == placeID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// Після оновлення даних або змін місць: новий стан/час зміни; видалене місце — завершити;
    /// минуло 8 год — завершити з підказкою запустити знову.
    static func update(places: [Place], snapshot: (Place) -> ScheduleSnapshot?, now: Date = .now) async {
        for activity in Activity<PlaceActivityAttributes>.activities where activity.activityState == .active {
            guard let place = places.first(where: { $0.id == activity.attributes.placeID }) else {
                LiveActivityKeepStore.shared.remove(activity.attributes.placeID)
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

    /// Коли застосунок на екрані (NOL-43): повернути змахнуті відліки й перезапустити ті, що близькі до 8 год.
    /// Запускати Live Activity можна лише з активного застосунку, тому фонове оновлення цього не робить.
    static func restore(places: [Place], snapshot: (Place) -> ScheduleSnapshot?, now: Date = .now) async {
        guard isAvailable else { return }
        var running: [UUID: Date] = [:]
        for activity in Activity<PlaceActivityAttributes>.activities where activity.activityState == .active {
            running[activity.attributes.placeID] = activity.content.state.startedAt
        }
        let store = LiveActivityKeepStore.shared
        let plan = LiveActivityRestorePlanner.plan(kept: store.placeIDs, running: running,
                                                   placeIDs: places.map(\.id), now: now)
        plan.forget.forEach(store.remove)
        for id in plan.start + plan.renew {
            guard let place = places.first(where: { $0.id == id }) else { continue }
            await start(place: place, snapshot: snapshot(place), now: now)
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
