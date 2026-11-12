import Foundation

/// Скільки хвилин доби (або періоду) було зі світлом, без світла і невідомо (NOL-25).
struct PowerMinutes: Equatable, Sendable {
    var available = 0
    var outage = 0
    var unknown = 0

    var total: Int { available + outage + unknown }

    static func + (a: PowerMinutes, b: PowerMinutes) -> PowerMinutes {
        PowerMinutes(available: a.available + b.available, outage: a.outage + b.outage, unknown: a.unknown + b.unknown)
    }
}

/// Статистика однієї доби. `minutes == nil` — графіка немає: «Невідомо», у підсумки не входить.
struct DayStatistics: Equatable, Sendable {
    let dateKey: String
    let minutes: PowerMinutes?
    /// Розбивка на ніч і день (NOL-26); nil разом із `minutes`.
    var night: PowerMinutes? = nil
    var daytime: PowerMinutes? = nil

    var isKnown: Bool { minutes != nil }
}

/// Скільки попередніх днів показувати в статистиці.
enum StatisticsPeriod: Int, CaseIterable, Identifiable, Sendable {
    case three = 3
    case seven = 7
    case fourteen = 14

    var id: Int { rawValue }
    var days: Int { rawValue }
    var title: String { self == .three ? "3 дні" : "\(rawValue) днів" }
}

/// Статистика місця: сьогодні, завтра (якщо опубліковано) і вибрані попередні дні з підсумком.
struct PlaceStatistics: Equatable, Sendable {
    let today: DayStatistics
    /// nil — графік на завтра ще не опубліковано.
    let tomorrow: DayStatistics?
    /// Попередні дні, новіші спочатку.
    let previous: [DayStatistics]

    /// Підсумок за попередні дні: лише дні з даними.
    var previousTotal: PowerMinutes { previous.compactMap(\.minutes).reduce(PowerMinutes(), +) }
    var previousNightTotal: PowerMinutes { previous.compactMap(\.night).reduce(PowerMinutes(), +) }
    var previousDayTotal: PowerMinutes { previous.compactMap(\.daytime).reduce(PowerMinutes(), +) }
    var knownPreviousDays: Int { previous.filter(\.isKnown).count }
    var unknownPreviousDays: Int { previous.count - knownPreviousDays }
}

enum StatisticsCalculator {
    /// Хвилини доби за станами. Неопублікований/нерозпізнаний графік → nil («Невідомо»).
    /// Дні переходу на літній/зимовий час рахуються за реальною тривалістю (23 / 25 год).
    static func minutes(of day: DaySchedule, calendar: Calendar = KyivTime.calendar) -> PowerMinutes? {
        minutes(of: day, within: [MinuteRange(start: 0, end: 1440)], calendar: calendar)
    }

    /// Те саме, але лише в межах `ranges` (напр., нічні проміжки).
    static func minutes(of day: DaySchedule, within ranges: [MinuteRange],
                        calendar: Calendar = KyivTime.calendar) -> PowerMinutes? {
        guard day.kind == .published else { return nil }
        let shift = dstShift(dateKey: day.dateKey, calendar: calendar)
        var result = PowerMinutes()
        for interval in day.intervals {
            for r in MinuteRange.normalized(ranges) {
                let a = max(interval.start, r.start), b = min(interval.end, r.end)
                guard a < b else { continue }
                var length = b - a
                if let shift {
                    let overlap = max(0, min(b, shift.range.end) - max(a, shift.range.start))
                    length += overlap * (shift.weight - 1)
                }
                switch interval.state {
                case .available: result.available += length
                case .outage: result.outage += length
                case .unknown: result.unknown += length
                }
            }
        }
        return result
    }

    static func day(_ day: DaySchedule, night: NightBounds = .default,
                    calendar: Calendar = KyivTime.calendar) -> DayStatistics {
        let all = minutes(of: day, calendar: calendar)
        guard all != nil else { return DayStatistics(dateKey: day.dateKey, minutes: nil) }
        let bounds = night.isValid ? night : .default
        return DayStatistics(dateKey: day.dateKey, minutes: all,
                             night: minutes(of: day, within: bounds.ranges, calendar: calendar),
                             daytime: minutes(of: day, within: bounds.dayRanges, calendar: calendar))
    }

    static func statistics(snapshot: ScheduleSnapshot?, subgroup: Subgroup, now: Date,
                           period: StatisticsPeriod, night: NightBounds = .default) -> PlaceStatistics {
        let p = SubgroupPresentation(snapshot: snapshot, subgroup: subgroup, now: now)
        let tomorrow = day(p.tomorrow, night: night)
        let previous = HistoryWindow.previousKeys(today: p.todayKey, days: period.days).map {
            day(HistoryWindow.pastSchedule(snapshot: snapshot, subgroup: subgroup, dateKey: $0), night: night)
        }
        return PlaceStatistics(today: day(p.today, night: night), tomorrow: tomorrow.isKnown ? tomorrow : nil,
                               previous: previous)
    }

    /// Хвилини «настінного годинника» доби, які не існують (weight 0, весна) або повторюються (weight 2, осінь).
    static func dstShift(dateKey: String, calendar: Calendar = KyivTime.calendar) -> (range: MinuteRange, weight: Int)? {
        let tz = calendar.timeZone
        let p = dateKey.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3,
              let start = calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2])),
              let next = calendar.date(byAdding: .day, value: 1, to: start),
              let transition = tz.nextDaylightSavingTimeTransition(after: start), transition < next
        else { return nil }
        let before = tz.secondsFromGMT(for: transition.addingTimeInterval(-1))
        let after = tz.secondsFromGMT(for: transition)
        let delta = (after - before) / 60
        // Хвилина доби за «старим» годинником, коли відбувається перехід.
        let minute = Int(transition.timeIntervalSince(start)) / 60
        if delta > 0 { return (MinuteRange(start: minute, end: min(1440, minute + delta)), 0) }
        if delta < 0 { return (MinuteRange(start: max(0, minute + delta), end: minute), 2) }
        return nil
    }
}

enum StatisticsFormat {
    /// «12 год 30 хв», «45 хв», «0 год».
    static func duration(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if m == 0 { return "\(h) год" }
        if h == 0 { return "\(m) хв" }
        return "\(h) год \(m) хв"
    }

    /// Частка часу без світла серед відомих хвилин, у відсотках (nil — немає відомих хвилин).
    static func outageShare(_ m: PowerMinutes) -> Int? {
        let known = m.available + m.outage
        guard known > 0 else { return nil }
        return Int((Double(m.outage) / Double(known) * 100).rounded())
    }
}
