import Foundation

/// Межі «ночі» для статистики (NOL-26). Хвилини доби 0...1439; ніч може переходити через північ.
struct NightBounds: Codable, Equatable, Sendable {
    var startMinute: Int
    var endMinute: Int

    /// 00:00–06:00 за замовчуванням.
    static let `default` = NightBounds(startMinute: 0, endMinute: 360)

    /// Однакові початок і кінець — некоректно (ніч нульової або цілодобової тривалості).
    var isValid: Bool {
        (0..<1440).contains(startMinute) && (0..<1440).contains(endMinute) && startMinute != endMinute
    }

    var crossesMidnight: Bool { startMinute > endMinute }

    /// Нічні проміжки в межах однієї календарної доби: один або два (якщо ніч переходить через північ).
    var ranges: [MinuteRange] {
        guard isValid else { return [] }
        if !crossesMidnight { return [MinuteRange(start: startMinute, end: endMinute)] }
        return [MinuteRange(start: 0, end: endMinute), MinuteRange(start: startMinute, end: 1440)]
            .filter(\.isValid)
    }

    /// Денні проміжки — доповнення до нічних.
    var dayRanges: [MinuteRange] {
        var out: [MinuteRange] = []
        var cursor = 0
        for r in ranges {
            if r.start > cursor { out.append(MinuteRange(start: cursor, end: r.start)) }
            cursor = r.end
        }
        if cursor < 1440 { out.append(MinuteRange(start: cursor, end: 1440)) }
        return out
    }

    /// «00:00–06:00».
    var title: String { KyivTime.minuteString(startMinute) + "–" + KyivTime.minuteString(endMinute) }
}
