import Foundation

/// Зміна графіка місця на конкретну добу (NOL-23; історія — NOL-24).
struct ScheduleChange: Codable, Equatable, Sendable {
    let placeID: UUID
    let dateKey: String
    let detectedAt: Date
    /// Відключення до зміни і після.
    let old: [MinuteRange]
    let new: [MinuteRange]
}

/// Що вже бачили для кожного місця: placeID → dateKey → відключення опублікованого графіка.
typealias SeenSchedules = [String: [String: [MinuteRange]]]

enum ScheduleChangeDetector {
    /// Порівнює поточні графіки (сьогодні й завтра) з тим, що бачили раніше.
    /// - Перша поява графіка на добу (зокрема «завтра») — не зміна, лише запам'ятовується.
    /// - Неопубліковані / невідомі дні не порівнюються.
    /// - Записи старші за історію (`AppConfig.historyDays`) і видалених місць прибираються.
    static func detect(places: [Place], snapshot: (Place) -> ScheduleSnapshot?, seen: inout SeenSchedules,
                       now: Date) -> [ScheduleChange] {
        let today = KyivTime.dateKey(for: now)
        let keys = [today, KyivTime.addingDays(1, to: today)]
        let oldest = HistoryWindow.oldestKey(today: today)
        var changes: [ScheduleChange] = []
        var next: SeenSchedules = [:]

        for place in places {
            var placeSeen = (seen[place.id.uuidString] ?? [:]).filter { $0.key >= oldest }
            if let snap = snapshot(place) {
                for key in keys {
                    let day = snap.schedule(for: place.subgroup, dateKey: key)
                    guard day.kind == .published else { continue }
                    let outages = day.intervals.filter { $0.state == .outage }.map { MinuteRange(start: $0.start, end: $0.end) }
                    if let previous = placeSeen[key], previous != outages {
                        changes.append(ScheduleChange(placeID: place.id, dateKey: key, detectedAt: now,
                                                      old: previous, new: outages))
                    }
                    placeSeen[key] = outages
                }
            }
            next[place.id.uuidString] = placeSeen
        }
        seen = next
        return changes
    }

    /// «Графік для «Робота» змінився» + стислий підсумок.
    static func message(for change: ScheduleChange, placeName: String, now: Date) -> (title: String, body: String) {
        let today = KyivTime.dateKey(for: now)
        let dayName: String
        if change.dateKey == today { dayName = "Сьогодні" }
        else if change.dateKey == KyivTime.addingDays(1, to: today) { dayName = "Завтра" }
        else { dayName = change.dateKey }
        return ("Графік для «\(placeName)» змінився",
                "\(dayName): \(describe(change.new)) (було: \(describe(change.old))).")
    }

    static func describe(_ ranges: [MinuteRange]) -> String {
        guard !ranges.isEmpty else { return "відключень немає" }
        return "відключення " + ranges.map { "\(KyivTime.minuteString($0.start))–\(KyivTime.minuteString($0.end))" }
            .joined(separator: ", ")
    }
}
