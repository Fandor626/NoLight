import Foundation

struct PowerStatus: Equatable, Sendable {
    var state: PowerState
    var changeAt: Date?
    var nextState: PowerState?
}

enum DataReliability: Equatable, Sendable {
    case fresh, stale, expired, none
}

struct AbsoluteInterval: Equatable, Sendable {
    var start: Date
    var end: Date
    var state: PowerState
}

enum StatusCalculator {
    /// Інтервали двох сусідніх діб в абсолютних датах; суміжні однакові стани зливаються.
    static func absoluteIntervals(today: DaySchedule, tomorrow: DaySchedule) -> [AbsoluteInterval] {
        var out: [AbsoluteInterval] = []
        for day in [today, tomorrow] {
            for i in day.intervals {
                guard let s = KyivTime.date(dateKey: day.dateKey, minute: i.start),
                      let e = KyivTime.date(dateKey: day.dateKey, minute: i.end) else { continue }
                if let last = out.last, last.state == i.state, last.end == s {
                    out[out.count - 1].end = e
                } else {
                    out.append(AbsoluteInterval(start: s, end: e, state: i.state))
                }
            }
        }
        return out
    }

    static func status(today: DaySchedule, tomorrow: DaySchedule, now: Date) -> PowerStatus {
        let intervals = absoluteIntervals(today: today, tomorrow: tomorrow)
        guard let idx = intervals.firstIndex(where: { $0.start <= now && now < $0.end }) else {
            return PowerStatus(state: .unknown, changeAt: nil, nextState: nil)
        }
        let current = intervals[idx]
        if idx + 1 < intervals.count {
            return PowerStatus(state: current.state, changeAt: current.end, nextState: intervals[idx + 1].state)
        }
        return PowerStatus(state: current.state, changeAt: nil, nextState: nil)
    }

    static func reliability(fetchedAt: Date?, now: Date) -> DataReliability {
        guard let fetchedAt else { return .none }
        let age = now.timeIntervalSince(fetchedAt)
        if age >= AppConfig.expiredAfter { return .expired }
        if age >= AppConfig.staleAfter { return .stale }
        return .fresh
    }
}

/// Готові до відображення дані для однієї підчерги в конкретний момент.
struct SubgroupPresentation: Sendable {
    let subgroup: Subgroup
    let now: Date
    let todayKey: String
    let tomorrowKey: String
    let today: DaySchedule
    let tomorrow: DaySchedule
    let reliability: DataReliability
    let status: PowerStatus
    let lastCheck: Date?

    init(snapshot: ScheduleSnapshot?, subgroup: Subgroup, now: Date) {
        let todayKey = KyivTime.dateKey(for: now)
        let tomorrowKey = KyivTime.addingDays(1, to: todayKey)
        let reliability = StatusCalculator.reliability(fetchedAt: snapshot?.fetchedAt, now: now)

        var today = snapshot?.schedule(for: subgroup, dateKey: todayKey)
            ?? .unknown(dateKey: todayKey, subgroup: subgroup, kind: .noData)
        var tomorrow = snapshot?.schedule(for: subgroup, dateKey: tomorrowKey)
            ?? .unknown(dateKey: tomorrowKey, subgroup: subgroup, kind: .noData)
        // Надто старі дані не видаємо за актуальні.
        if reliability == .expired || reliability == .none {
            today = .unknown(dateKey: todayKey, subgroup: subgroup, kind: .noData)
            tomorrow = .unknown(dateKey: tomorrowKey, subgroup: subgroup, kind: .noData)
        }

        self.subgroup = subgroup
        self.now = now
        self.todayKey = todayKey
        self.tomorrowKey = tomorrowKey
        self.today = today
        self.tomorrow = tomorrow
        self.reliability = reliability
        self.status = StatusCalculator.status(today: today, tomorrow: tomorrow, now: now)
        self.lastCheck = snapshot?.fetchedAt
    }

    var minuteNow: Int { KyivTime.minutes(of: now) }
    var showsStaleWarning: Bool { reliability == .stale }

    var headline: String {
        switch status.state {
        case .available: return "Світло є"
        case .outage: return "Світла немає"
        case .unknown:
            switch today.kind {
            case .notPublished: return "Графік не опубліковано"
            case .subgroupNotListed: return "Підчерги немає в графіку"
            case .parseFailed: return "Графік не розпізнано"
            case .noData: return reliability == .none ? "Даних ще немає" : "Немає актуальних даних"
            case .published: return "Статус невідомий"
            }
        }
    }

    var detail: String? {
        guard let at = status.changeAt else {
            return status.state == .available && today.kind == .published ? "Відключень не заплановано" : nil
        }
        let t = timeLabel(at)
        switch (status.state, status.nextState) {
        case (.available, .some(.outage)): return "Відключення о \(t)"
        case (.available, _): return "Графік після \(t) невідомий"
        case (.outage, .some(.available)): return "Світло з’явиться о \(t)"
        case (.outage, _): return "Графік після \(t) невідомий"
        case (.unknown, _): return "Графік відомий з \(t)"
        }
    }

    var updatedText: String? {
        guard let lastCheck else { return nil }
        let sameDay = KyivTime.dateKey(for: lastCheck) == todayKey
        return "Оновлено " + (sameDay ? KyivTime.timeString(lastCheck) : KyivTime.shortDateTimeString(lastCheck))
    }

    private func timeLabel(_ date: Date) -> String {
        if let tomorrowStart = KyivTime.startOfDay(dateKey: tomorrowKey), date == tomorrowStart { return "24:00" }
        let key = KyivTime.dateKey(for: date)
        return key == todayKey ? KyivTime.timeString(date) : KyivTime.timeString(date) + " (завтра)"
    }
}
