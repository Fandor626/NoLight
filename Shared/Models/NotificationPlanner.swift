import Foundation

/// Заплановане локальне сповіщення (без залежності від UserNotifications — чиста логіка, тестується).
struct PlannedNotification: Equatable, Sendable {
    enum Kind: String, Sendable { case outage, powerReturn }

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

/// Планує попередження перед відключеннями (NOL-21) і перед поверненням світла (NOL-22) за кешованими графіками.
/// iOS тримає не більше 64 очікуваних локальних сповіщень, тому плануємо лише найближчі
/// й переплановуємо після кожного оновлення, відкриття застосунку та зміни місць.
enum NotificationPlanner {
    static let iOSLimit = 64
    static let idPrefix = "nolight."

    static func plan(places: [Place], snapshot: (Place) -> ScheduleSnapshot?, now: Date,
                     limit: Int = iOSLimit) -> [PlannedNotification] {
        var out: [PlannedNotification] = []
        for place in places {
            guard place.warnBeforeOutageMinutes != nil || place.warnBeforeReturnMinutes != nil else { continue }
            let p = SubgroupPresentation(snapshot: snapshot(place), subgroup: place.subgroup, now: now)
            // Протерміновані/відсутні дані вже перетворені на «невідомо» — для них нічого не плануємо.
            let intervals = StatusCalculator.absoluteIntervals(today: p.today, tomorrow: p.tomorrow)
            for (index, interval) in intervals.enumerated() {
                let previous = index > 0 ? intervals[index - 1].state : nil
                // Початок відключення.
                if interval.state == .outage, previous != .outage, let lead = place.warnBeforeOutageMinutes {
                    let fire = interval.start.addingTimeInterval(-TimeInterval(lead * 60))
                    if fire > now {
                        out.append(PlannedNotification(
                            id: id(place: place, kind: .outage, event: interval.start),
                            placeID: place.id, kind: .outage, fireDate: fire, eventDate: interval.start,
                            title: "«\(place.name)»: відключення о \(KyivTime.timeString(interval.start))",
                            body: "Через \(lead) хв за графіком не буде світла (підчерга \(place.subgroup.id))."))
                    }
                }
                // Повернення світла: відключення переходить у «є світло» (не в «невідомо»).
                if interval.state == .available, previous == .outage, let lead = place.warnBeforeReturnMinutes {
                    let fire = interval.start.addingTimeInterval(-TimeInterval(lead * 60))
                    if fire > now {
                        out.append(PlannedNotification(
                            id: id(place: place, kind: .powerReturn, event: interval.start),
                            placeID: place.id, kind: .powerReturn, fireDate: fire, eventDate: interval.start,
                            title: "«\(place.name)»: світло о \(KyivTime.timeString(interval.start))",
                            body: "Через \(lead) хв за графіком повернеться світло (підчерга \(place.subgroup.id))."))
                    }
                }
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
