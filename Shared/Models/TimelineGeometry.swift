import Foundation

enum TimelineGeometry {
    static func fraction(minute: Int) -> Double { Double(min(max(minute, 0), 1440)) / 1440 }
    static func markerX(minute: Int, width: Double) -> Double { fraction(minute: minute) * width }

    /// Центр підпису поточного часу, щоб він не виходив за межі смуги.
    static func clampedLabelCenter(x: Double, labelWidth: Double, containerWidth: Double) -> Double {
        let half = labelWidth / 2
        return min(max(x, half), max(half, containerWidth - half))
    }

    static func segmentFrames(_ intervals: [ScheduleInterval], width: Double) -> [(x: Double, width: Double, state: PowerState)] {
        intervals.map {
            (x: fraction(minute: $0.start) * width,
             width: max(0, Double($0.end - $0.start) / 1440 * width),
             state: $0.state)
        }
    }
}

/// Коли WidgetKit має показати нову "картку": зміна стану, кожні 15 хв (рух маркера), моменти застарівання даних.
enum WidgetTimelinePlanner {
    static func entryDates(now: Date, snapshot: ScheduleSnapshot?, subgroup: Subgroup,
                           horizon: TimeInterval = 24 * 3600) -> [Date] {
        let end = now.addingTimeInterval(horizon)
        var set: Set<Date> = [now]

        let step: TimeInterval = 15 * 60
        let nowRef = now.timeIntervalSinceReferenceDate
        var t = (floor(nowRef / step) + 1) * step
        while t <= nowRef + 12 * 3600 {
            set.insert(Date(timeIntervalSinceReferenceDate: t))
            t += step
        }

        let todayKey = KyivTime.dateKey(for: now)
        let tomorrowKey = KyivTime.addingDays(1, to: todayKey)
        let today = snapshot?.schedule(for: subgroup, dateKey: todayKey)
            ?? .unknown(dateKey: todayKey, subgroup: subgroup, kind: .noData)
        let tomorrow = snapshot?.schedule(for: subgroup, dateKey: tomorrowKey)
            ?? .unknown(dateKey: tomorrowKey, subgroup: subgroup, kind: .noData)
        for interval in StatusCalculator.absoluteIntervals(today: today, tomorrow: tomorrow) {
            for d in [interval.start, interval.end] where d > now && d <= end { set.insert(d) }
        }

        if let fetched = snapshot?.fetchedAt {
            for offset in [AppConfig.staleAfter, AppConfig.expiredAfter] {
                let d = fetched.addingTimeInterval(offset)
                if d > now && d <= end { set.insert(d) }
            }
        }
        return set.sorted()
    }
}
