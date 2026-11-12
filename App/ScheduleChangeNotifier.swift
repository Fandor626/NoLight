import Foundation
import UserNotifications

/// Сповіщення про зміну графіка місця (NOL-23). Виявлення — `ScheduleChangeDetector`, стан — `ScheduleSeenStore`.
enum ScheduleChangeNotifier {
    static let idPrefix = "nolight-change."   // інший префікс, ніж у запланованих попереджень: replan їх не чіпає

    /// Повертає виявлені зміни (для історії, NOL-24) і надсилає сповіщення для місць, де їх увімкнено.
    @discardableResult
    static func process(places: [Place], snapshot: (Place) -> ScheduleSnapshot?, now: Date = Date(),
                        store: ScheduleSeenStore = .shared) async -> [ScheduleChange] {
        var seen = store.seen
        let changes = ScheduleChangeDetector.detect(places: places, snapshot: snapshot, seen: &seen, now: now)
        store.seen = seen
        guard !changes.isEmpty else { return [] }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return changes
        }
        for change in changes {
            guard let place = places.first(where: { $0.id == change.placeID }), place.notifiesScheduleChanges else { continue }
            let text = ScheduleChangeDetector.message(for: change, placeName: place.name, now: now)
            let content = UNMutableNotificationContent()
            content.title = text.title
            content.body = text.body
            content.sound = .default
            content.threadIdentifier = place.id.uuidString
            let id = "\(idPrefix)\(place.id.uuidString).\(change.dateKey).\(Int(now.timeIntervalSince1970))"
            try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
        }
        return changes
    }

    /// Для фонового завдання: місця й кеш з App Group.
    @discardableResult
    static func processFromStores() async -> [ScheduleChange] {
        let places = PlaceStore.shared.places
        var snapshots: [ScheduleSourceKey: ScheduleSnapshot] = [:]
        for key in ScheduleSourceKey.active(for: places) {
            snapshots[key] = FileScheduleCache.appGroup(for: key).load()
        }
        return await process(places: places, snapshot: { snapshots[$0.sourceKey] })
    }
}
