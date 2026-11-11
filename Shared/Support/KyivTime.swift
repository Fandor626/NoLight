import Foundation

/// Усі розрахунки часу — за київським часом, незалежно від часового поясу пристрою.
enum KyivTime {
    static let timeZone: TimeZone =
        TimeZone(identifier: "Europe/Kyiv") ?? TimeZone(identifier: "Europe/Kiev") ?? TimeZone(secondsFromGMT: 2 * 3600)!

    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = timeZone
        c.locale = Locale(identifier: "uk_UA")
        return c
    }()

    static func dateKey(for date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private static func parts(of key: String) -> (y: Int, m: Int, d: Int)? {
        let p = key.split(separator: "-")
        guard p.count == 3, let y = Int(p[0]), let m = Int(p[1]), let d = Int(p[2]) else { return nil }
        return (y, m, d)
    }

    static func startOfDay(dateKey: String) -> Date? {
        guard let p = parts(of: dateKey),
              let d = calendar.date(from: DateComponents(year: p.y, month: p.m, day: p.d, hour: 0, minute: 0, second: 0))
        else { return nil }
        return calendar.startOfDay(for: d)
    }

    /// Хвилини від початку доби (0...1439).
    static func minutes(of date: Date) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    /// Абсолютна дата для "хвилини доби". 1440 = початок наступної доби.
    static func date(dateKey: String, minute: Int) -> Date? {
        guard let start = startOfDay(dateKey: dateKey) else { return nil }
        if minute >= 1440 { return calendar.date(byAdding: .day, value: minute / 1440, to: start) }
        return calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: start, matchingPolicy: .nextTime)
    }

    static func addingDays(_ n: Int, to key: String) -> String {
        guard let start = startOfDay(dateKey: key), let d = calendar.date(byAdding: .day, value: n, to: start) else { return key }
        return dateKey(for: d)
    }

    /// Ключ доби за "10 листопада": рік підбирається так, щоб дата була найближчою до reference.
    static func dateKey(day: Int, month: Int, reference: Date) -> String? {
        let refYear = calendar.component(.year, from: reference)
        var best: (key: String, distance: TimeInterval)?
        for y in [refYear - 1, refYear, refYear + 1] {
            guard let d = calendar.date(from: DateComponents(year: y, month: month, day: day, hour: 12)) else { continue }
            let r = calendar.dateComponents([.year, .month, .day], from: d)
            guard r.year == y, r.month == month, r.day == day else { continue }
            let dist = abs(d.timeIntervalSince(reference))
            if best == nil || dist < best!.distance {
                best = (String(format: "%04d-%02d-%02d", y, month, day), dist)
            }
        }
        return best?.key
    }

    static func minuteString(_ minute: Int) -> String { String(format: "%02d:%02d", minute / 60, minute % 60) }
    static func timeString(_ date: Date) -> String { minuteString(minutes(of: date)) }

    static func longDateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "uk_UA")
        f.timeZone = timeZone
        f.dateFormat = "EEEE, d MMMM"
        return f.string(from: date)
    }

    static func shortDateTimeString(_ date: Date) -> String {
        let c = calendar.dateComponents([.day, .month, .hour, .minute], from: date)
        return String(format: "%02d.%02d %02d:%02d", c.day ?? 0, c.month ?? 0, c.hour ?? 0, c.minute ?? 0)
    }
}
