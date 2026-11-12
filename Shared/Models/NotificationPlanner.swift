import Foundation

/// Заплановане локальне сповіщення (без залежності від UserNotifications — чиста логіка, тестується).
struct PlannedNotification: Equatable, Sendable {
    enum Kind: String, Sendable { case outage }

    let id: String
    let placeID: UUID
    let kind: Kind
    /// Коли показати сповіщення.
    let fireDate: Date
    /// Момент самої зміни (початок відключення).
    let eventDate: Date
    let title: String
    let body: String
}

/// Планує попередження перед відключеннями за кешованими графіками (NOL-21).
/// iOS тримає не більше 64 очікуваних локальних сповіщень, тому плануємо лише найближчі
/// й переплановуємо після кожного оновлення, відкриття застосунку та зміни місць.
enum NotificationPlanner {
    static let iOSLimit = 64
    static let idPrefix = "nolight."

    static func plan(places: [Place], snapshot: (Place) -> ScheduleSnapshot?, now: Date,
                     limit: Int = iOSLimit) -> [PlannedNotification] {
        var out: [PlannedNotification] = []
        for place in places {
            guard let lead = place.warnBeforeOutageMinutes else { continue }
            let p = SubgroupPresentation(snapshot: snapshot(place), subgroup: place.subgroup, now: now)
            // Протерміновані/відсутні дані вже перетворені на «невідомо» — для них нічого не плануємо.
            let intervals = StatusCalculator.absoluteIntervals(today: p.today, tomorrow: p.tomorrow)
            for (index, interval) in intervals.enumerated() where interval.state == .outage {
                let previous = index > 0 ? intervals[index - 1].state : nil
                guard previous != .outage else { continue }
                let fire = interval.start.addingTimeInterval(-TimeInterval(lead * 60))
                guard fire > now else { continue }
                out.append(PlannedNotification(
                    id: id(place: place, kind: .outage, event: interval.start),
                    placeID: place.id, kind: .outage, fireDate: fire, eventDate: interval.start,
                    title: "«\(place.name)»: відключення о \(KyivTime.timeString(interval.start))",
                    body: "Через \(lead) хв за графіком не буде світла (підчерга \(place.subgroup.id))."))
            }
        }
        return Array(out.sorted { ($0.fireDate, $0.id) < ($1.fireDate, $1.id) }.prefix(max(limit, 0)))
    }

    static func id(place: Place, kind: PlannedNotification.Kind, event: Date) -> String {
        "\(idPrefix)\(place.id.uuidString).\(kind.rawValue).\(Int(event.timeIntervalSince1970))"
    }

    /// Що прибрати й що додати, щоб очікувані сповіщення збіглися з планом.
    static func diff(pendingIDs: [String], plan: [PlannedNotification]) -> (remove: [String], add: [PlannedNotification]) {
        let ours = pendingIDs.filter { $0.hasPrefix(idPrefix) }
        let planned = Set(plan.map(\.id))
        let pending = Set(ours)
        return (ours.filter { !planned.contains($0) }, plan.filter { !pending.contains($0.id) })
    }
}
