import Foundation

/// Розбір файлу області з API OE_OUTAGE_DATA (github.com/yaroslav2901/OE_OUTAGE_DATA, `data/<область>.json`).
///
/// Формат (перевірено на реальних файлах 12.11.2026):
/// `fact.data` — словник «unix-час початку доби → {"GPV1.1": {"1": "yes", … "24": "no"}, …}`.
/// Година "h" — проміжок (h−1):00…h:00 за Києвом. Значення:
/// - `yes` — світло є; `no` — світла немає;
/// - `first` / `second` — світла не буде перші / другі 30 хв;
/// - `mfirst` / `msecond` — **можливе** відключення перші / другі 30 хв → вважаємо відключенням
///   (застосунок не обіцяє світло, коли його може не бути — NFR6);
/// - будь-яке інше значення → «невідомо» для цієї години.
enum OutageDataParser {
    struct Result: Equatable, Sendable {
        let regionID: String
        let updatedAt: Date?
        let posts: [String: PublishedSchedulePost]
    }

    private struct File: Decodable {
        let regionId: String?
        let lastUpdated: String?
        let fact: Fact?
        struct Fact: Decodable {
            let data: [String: [String: [String: String]]]?
        }
    }

    static func parse(_ data: Data, sourceURL: URL) throws -> Result {
        let file: File
        do { file = try JSONDecoder().decode(File.self, from: data) }
        catch { throw ScheduleError.parsingFailed("Файл API має невідомий формат.") }
        guard let days = file.fact?.data else { throw ScheduleError.structureChanged }

        let updatedAt = file.lastUpdated.flatMap(parseISO)
        var posts: [String: PublishedSchedulePost] = [:]
        for (timestamp, groups) in days {
            guard let seconds = TimeInterval(timestamp) else { continue }
            // Деякі файли дають північ за Києвом, інші — північ UTC; обидва варіанти припадають на ту саму київську дату.
            let dateKey = KyivTime.dateKey(for: Date(timeIntervalSince1970: seconds))
            var outages: [String: [MinuteRange]] = [:]
            var unknown: [String: [MinuteRange]] = [:]
            for (group, hours) in groups {
                guard let subgroup = subgroupID(fromGroup: group) else { continue }
                let parsed = parseHours(hours)
                outages[subgroup] = parsed.outages
                if !parsed.unknown.isEmpty { unknown[subgroup] = parsed.unknown }
            }
            guard !outages.isEmpty else { continue }
            posts[dateKey] = PublishedSchedulePost(
                dateKey: dateKey, publishedAt: updatedAt ?? Date(timeIntervalSince1970: seconds),
                sourceURL: sourceURL, title: "OE_OUTAGE_DATA · \(file.regionId ?? "")",
                outages: outages, spillover: [:], unknown: unknown.isEmpty ? nil : unknown)
        }
        return Result(regionID: file.regionId ?? "", updatedAt: updatedAt, posts: posts)
    }

    /// "GPV3.2" → "3.2"; інші ключі ігноруються.
    static func subgroupID(fromGroup group: String) -> String? {
        guard group.hasPrefix("GPV") else { return nil }
        return Subgroup(id: String(group.dropFirst(3)))?.id
    }

    /// Години "1"…"24" → проміжки відключень і невідомого (у хвилинах доби). Відсутня година → «невідомо».
    static func parseHours(_ hours: [String: String]) -> (outages: [MinuteRange], unknown: [MinuteRange]) {
        var outages: [MinuteRange] = []
        var unknown: [MinuteRange] = []
        for hour in 1...24 {
            let start = (hour - 1) * 60, mid = start + 30, end = hour * 60
            switch hours[String(hour)]?.lowercased() {
            case "yes": break
            case "no": outages.append(.init(start: start, end: end))
            case "first", "mfirst": outages.append(.init(start: start, end: mid))
            case "second", "msecond": outages.append(.init(start: mid, end: end))
            default: unknown.append(.init(start: start, end: end))
            }
        }
        return (MinuteRange.normalized(outages), MinuteRange.normalized(unknown))
    }

    private static func parseISO(_ text: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }
}
