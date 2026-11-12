import Foundation

/// Тексти й значення для ускладнень годинника (NOL-47), без WidgetKit — тестуються окремо.
enum WatchComplication {
    /// Однорядкове ускладнення: «Світло до 18:00», «Без світла до 20:30 (завтра)», «Світло: невідомо».
    static func inline(_ status: PowerStatus, now: Date) -> String {
        guard let at = status.changeAt else {
            switch status.state {
            case .available: return "Світло є"
            case .outage: return "Без світла"
            case .unknown: return "Світло: невідомо"
            }
        }
        let time = timeLabel(at, now: now)
        switch status.state {
        case .available: return "Світло до \(time)"
        case .outage: return "Без світла до \(time)"
        case .unknown: return "Невідомо до \(time)"
        }
    }

    /// Частка поточного проміжку, що вже минула (0...1) — для кільця. nil — зміни не видно.
    static func progress(today: DaySchedule, tomorrow: DaySchedule, now: Date) -> Double? {
        let intervals = StatusCalculator.absoluteIntervals(today: today, tomorrow: tomorrow)
        guard let idx = intervals.firstIndex(where: { $0.start <= now && now < $0.end }),
              idx + 1 < intervals.count else { return nil }
        let i = intervals[idx]
        let total = i.end.timeIntervalSince(i.start)
        guard total > 0 else { return nil }
        return min(1, max(0, now.timeIntervalSince(i.start) / total))
    }

    /// Високий пріоритет у Smart Stack за 30 хв до зміни і до її настання.
    static func relevance(changeAt: Date?, now: Date, window: TimeInterval = 30 * 60) -> Double {
        guard let changeAt, changeAt > now else { return 0.1 }
        return changeAt.timeIntervalSince(now) <= window ? 1.0 : 0.2
    }

    static func timeLabel(_ date: Date, now: Date) -> String {
        let todayKey = KyivTime.dateKey(for: now)
        if let midnight = KyivTime.startOfDay(dateKey: KyivTime.addingDays(1, to: todayKey)), date == midnight {
            return "24:00"
        }
        return KyivTime.dateKey(for: date) == todayKey ? KyivTime.timeString(date) : KyivTime.timeString(date) + " (завтра)"
    }
}
