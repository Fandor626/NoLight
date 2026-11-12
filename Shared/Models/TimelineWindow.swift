import Foundation

/// Коротка шкала навколо «зараз» для Apple Watch (NOL-46): від −2 год до +2 год.
/// Частини, для яких графіка немає (вчора не збережено, завтра не опубліковано), — «невідомо».
struct TimelineWindowSegment: Equatable, Sendable {
    /// Частки ширини шкали 0...1.
    var start: Double
    var end: Double
    var state: PowerState
}

struct TimelineWindowData: Equatable, Sendable {
    let from: Date
    let to: Date
    let segments: [TimelineWindowSegment]
    /// Моменти змін усередині вікна (частки 0...1).
    let changes: [Double]
    /// Позначка «зараз» (частка 0...1).
    let nowFraction: Double
}

enum TimelineWindow {
    static let before: TimeInterval = 2 * 3600
    static let after: TimeInterval = 2 * 3600

    static func make(snapshot: ScheduleSnapshot?, subgroup: Subgroup, now: Date,
                     before: TimeInterval = before, after: TimeInterval = after) -> TimelineWindowData {
        let from = now.addingTimeInterval(-before)
        let to = now.addingTimeInterval(after)
        let p = SubgroupPresentation(snapshot: snapshot, subgroup: subgroup, now: now)
        let yesterdayKey = KyivTime.addingDays(-1, to: p.todayKey)
        // Застарілі дані не показуємо як актуальні — і вчорашній графік теж.
        let usable = !(p.reliability == .expired || p.reliability == .none)
        let yesterday = usable
            ? HistoryWindow.pastSchedule(snapshot: snapshot, subgroup: subgroup, dateKey: yesterdayKey)
            : .unknown(dateKey: yesterdayKey, subgroup: subgroup, kind: .noData)
        let intervals = absoluteIntervals([yesterday, p.today, p.tomorrow])
        return clip(intervals, from: from, to: to, now: now)
    }

    /// Абсолютні інтервали кількох діб; суміжні однакові стани зливаються.
    static func absoluteIntervals(_ days: [DaySchedule]) -> [AbsoluteInterval] {
        var out: [AbsoluteInterval] = []
        for day in days {
            for i in day.intervals {
                guard let s = KyivTime.date(dateKey: day.dateKey, minute: i.start),
                      let e = KyivTime.date(dateKey: day.dateKey, minute: i.end), s < e else { continue }
                if let last = out.last, last.state == i.state, last.end == s {
                    out[out.count - 1].end = e
                } else {
                    out.append(AbsoluteInterval(start: s, end: e, state: i.state))
                }
            }
        }
        return out
    }

    static func clip(_ intervals: [AbsoluteInterval], from: Date, to: Date, now: Date) -> TimelineWindowData {
        let total = to.timeIntervalSince(from)
        func f(_ d: Date) -> Double { min(1, max(0, d.timeIntervalSince(from) / total)) }
        var segments: [TimelineWindowSegment] = []
        var cursor = from
        for i in intervals where i.end > from && i.start < to {
            let s = max(i.start, from), e = min(i.end, to)
            if s > cursor { append(&segments, TimelineWindowSegment(start: f(cursor), end: f(s), state: .unknown)) }
            append(&segments, TimelineWindowSegment(start: f(s), end: f(e), state: i.state))
            cursor = e
        }
        if cursor < to { append(&segments, TimelineWindowSegment(start: f(cursor), end: 1, state: .unknown)) }
        let changes = segments.dropFirst().map(\.start)
        return TimelineWindowData(from: from, to: to, segments: segments, changes: Array(changes), nowFraction: f(now))
    }

    private static func append(_ list: inout [TimelineWindowSegment], _ s: TimelineWindowSegment) {
        guard s.end > s.start else { return }
        if let last = list.last, last.state == s.state, abs(last.end - s.start) < 1e-9 {
            list[list.count - 1].end = s.end
        } else {
            list.append(s)
        }
    }
}
