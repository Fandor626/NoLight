import Foundation
import UserNotifications

/// Синхронізує локальні сповіщення з планом `NotificationPlanner` (NOL-21).
enum NotificationScheduler {
    private static var center: UNUserNotificationCenter { .current() }

    /// Запитує дозвіл (при першому ввімкненні попередження). Повертає, чи дозволено.
    @discardableResult
    static func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Перепланування: прибирає зайві наші сповіщення (видалене місце, змінений графік) і додає нові.
    static func replan(places: [Place], snapshot: (Place) -> ScheduleSnapshot?, now: Date = Date()) async {
        let plan = NotificationPlanner.plan(places: places, snapshot: snapshot, now: now)
        let pending = await center.pendingNotificationRequests().map(\.identifier)
        let diff = NotificationPlanner.diff(pendingIDs: pending, plan: plan)
        if !diff.remove.isEmpty { center.removePendingNotificationRequests(withIdentifiers: diff.remove) }
        guard !diff.add.isEmpty else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        for item in diff.add {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default
            content.threadIdentifier = item.placeID.uuidString
            var components = KyivTime.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: item.fireDate)
            components.timeZone = KyivTime.timeZone
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: trigger))
        }
    }

    /// Для фонового завдання: місця й кеш читаються з App Group.
    static func replanFromStores() async {
        let places = PlaceStore.shared.places
        var snapshots: [ScheduleSourceKey: ScheduleSnapshot] = [:]
        for key in ScheduleSourceKey.active(for: places) {
            snapshots[key] = FileScheduleCache.appGroup(for: key).load()
        }
        await replan(places: places, snapshot: { snapshots[$0.sourceKey] })
    }
}
