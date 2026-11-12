import Foundation

/// Як задано приїзд на екрані «Подорож» (NOL-29).
enum ArrivalInput: Equatable, Sendable {
    /// Час за київським годинником (хвилина доби). Якщо він уже минув сьогодні — це завтра.
    case time(minute: Int)
    /// Тривалість поїздки від «зараз», у хвилинах.
    case duration(minutes: Int)
}

/// Стан світла в момент приїзду та наступна зміна після нього.
struct ArrivalForecast: Equatable, Sendable {
    let arrival: Date
    /// 0 — сьогодні, 1 — завтра, 2+ — пізніше (графіка ще немає).
    let dayOffset: Int
    let status: PowerStatus

    var headline: String {
        switch status.state {
        case .available: return "Світло буде"
        case .outage: return "Світла не буде"
        case .unknown: return HistoryWindow.unknownTitle
        }
    }

    /// «Відключення о 20:00», «Світло з’явиться о 01:00 (завтра)»…
    func detail(now: Date) -> String? {
        if status.state == .unknown {
            return dayOffset >= 2 ? "Графіки публікують лише на сьогодні й завтра."
                                  : "Графік на цей час ще не опубліковано або дані застаріли."
        }
        guard let at = status.changeAt else { return nil }
        let t = ArrivalForecast.label(at, now: now)
        switch (status.state, status.nextState) {
        case (.available, .some(.outage)): return "Далі відключення о \(t)"
        case (.outage, .some(.available)): return "Світло з’явиться о \(t)"
        default: return "Графік після \(t) невідомий"
        }
    }

    /// «Приїзд сьогодні о 18:30», «Приїзд завтра о 01:15», «Приїзд 14.11 09:00».
    func arrivalText(now: Date) -> String {
        "Приїзд " + ArrivalForecast.label(arrival, now: now, withDayWord: true)
    }

    static func label(_ date: Date, now: Date, withDayWord: Bool = false) -> String {
        let today = KyivTime.dateKey(for: now)
        let key = KyivTime.dateKey(for: date)
        let time = KyivTime.timeString(date)
        if key == today { return withDayWord ? "сьогодні о \(time)" : time }
        if key == KyivTime.addingDays(1, to: today) { return withDayWord ? "завтра о \(time)" : "\(time) (завтра)" }
        return KyivTime.shortDateTimeString(date)
    }
}

enum ArrivalCalculator {
    /// Найбільша тривалість поїздки, яку можна задати (48 год).
    static let maxDurationMinutes = 48 * 60

    static func arrivalDate(_ input: ArrivalInput, now: Date) -> Date {
        switch input {
        case .duration(let minutes):
            return now.addingTimeInterval(TimeInterval(max(0, min(minutes, maxDurationMinutes)) * 60))
        case .time(let minute):
            let m = max(0, min(minute, 1439))
            let today = KyivTime.dateKey(for: now)
            let key = m < KyivTime.minutes(of: now) ? KyivTime.addingDays(1, to: today) : today
            return KyivTime.date(dateKey: key, minute: m) ?? now
        }
    }

    /// Використовує графіки сьогодні/завтра (з урахуванням застарілих даних); пізніше — «Невідомо».
    static func forecast(snapshot: ScheduleSnapshot?, subgroup: Subgroup, now: Date, input: ArrivalInput) -> ArrivalForecast {
        let arrival = arrivalDate(input, now: now)
        let p = SubgroupPresentation(snapshot: snapshot, subgroup: subgroup, now: now)
        let offset = dayOffset(of: arrival, now: now)
        let status = offset <= 1
            ? StatusCalculator.status(today: p.today, tomorrow: p.tomorrow, now: arrival)
            : PowerStatus(state: .unknown, changeAt: nil, nextState: nil)
        return ArrivalForecast(arrival: arrival, dayOffset: offset, status: status)
    }

    static func dayOffset(of date: Date, now: Date) -> Int {
        let today = KyivTime.dateKey(for: now)
        let key = KyivTime.dateKey(for: date)
        var offset = 0
        var cursor = today
        while cursor < key && offset < 400 {
            cursor = KyivTime.addingDays(1, to: cursor)
            offset += 1
        }
        return offset
    }
}
