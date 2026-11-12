import Foundation

/// Порівняння графіків двох джерел для однієї підчерги й доби (NOL-18).
enum SourceComparison {
    /// Хвилинні проміжки, де стан відрізняється. Порівнюються лише опубліковані графіки обох джерел;
    /// якщо хоч одного немає — різниці не рахуємо (екран показує, якого джерела бракує).
    static func differences(_ a: DaySchedule, _ b: DaySchedule) -> [MinuteRange] {
        guard a.kind == .published, b.kind == .published else { return [] }
        var out: [MinuteRange] = []
        var start: Int?
        for m in 0..<1440 {
            let differs = a.state(atMinute: m) != b.state(atMinute: m)
            if differs, start == nil { start = m }
            if !differs, let s = start { out.append(.init(start: s, end: m)); start = nil }
        }
        if let s = start { out.append(.init(start: s, end: 1440)) }
        return out
    }

    /// Скільки хвилин відрізняється.
    static func differingMinutes(_ ranges: [MinuteRange]) -> Int { ranges.reduce(0) { $0 + $1.end - $1.start } }
}
