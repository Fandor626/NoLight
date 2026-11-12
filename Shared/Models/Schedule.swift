import Foundation

/// Відсутність даних НІКОЛИ не трактується як `available`.
enum PowerState: String, Codable, Sendable {
    case available
    case outage
    case unknown
}

/// Проміжок у хвилинах від початку доби: 0...1440, start < end. 1440 = 24:00.
struct MinuteRange: Codable, Hashable, Sendable {
    var start: Int
    var end: Int

    var isValid: Bool { 0 <= start && start < end && end <= 1440 }

    /// Сортує, відкидає некоректні, зливає перетини та суміжні проміжки.
    static func normalized(_ ranges: [MinuteRange]) -> [MinuteRange] {
        let sorted = ranges.filter { $0.isValid }.sorted { $0.start < $1.start }
        var out: [MinuteRange] = []
        for r in sorted {
            if let last = out.last, r.start <= last.end {
                out[out.count - 1].end = max(last.end, r.end)
            } else {
                out.append(r)
            }
        }
        return out
    }
}

struct ScheduleInterval: Codable, Hashable, Sendable {
    var start: Int
    var end: Int
    var state: PowerState

    var duration: Int { end - start }
    func contains(_ minute: Int) -> Bool { minute >= start && minute < end }
}

/// Чому для доби немає (повного) графіка.
enum DayScheduleKind: String, Codable, Sendable {
    case published
    case subgroupNotListed
    case notPublished
    case parseFailed
    case noData
}

extension DayScheduleKind {
    /// Короткий заголовок замість шкали, коли графіка немає (nil для опублікованого).
    var placeholderTitle: String? {
        switch self {
        case .published: return nil
        case .notPublished: return "Графік ще не опублікований"
        case .subgroupNotListed: return "Підчерги немає в графіку"
        case .parseFailed: return "Графік не розпізнано"
        case .noData: return "Немає актуальних даних"
        }
    }

    /// Пояснення під заголовком.
    var placeholderMessage: String? {
        switch self {
        case .published: return nil
        case .notPublished: return "Графік на цю добу ще не опубліковано. Це не означає, що відключень не буде."
        case .subgroupNotListed: return "У опублікованому графіку немає цієї підчерги."
        case .parseFailed: return "Графік опубліковано, але програма не змогла його розпізнати."
        case .noData: return "Немає актуальних даних. Оновіть графік, коли з’явиться інтернет."
        }
    }
}

/// Графік однієї підчерги на одну добу. `intervals` завжди повністю покривають 0...1440.
struct DaySchedule: Codable, Equatable, Sendable {
    let dateKey: String
    let subgroup: Subgroup
    let kind: DayScheduleKind
    let intervals: [ScheduleInterval]
    let source: URL?
    let publishedAt: Date?

    /// `unknown` — проміжки, для яких джерело дало незрозуміле значення (NOL-15): вони «невідомо», не «є світло».
    /// Відключення має пріоритет над «невідомо».
    static func build(dateKey: String, subgroup: Subgroup, outages: [MinuteRange], unknown: [MinuteRange] = [],
                      source: URL?, publishedAt: Date?) -> DaySchedule {
        var state = [PowerState](repeating: .available, count: 1440)
        for r in MinuteRange.normalized(unknown) { for m in r.start..<r.end { state[m] = .unknown } }
        for r in MinuteRange.normalized(outages) { for m in r.start..<r.end { state[m] = .outage } }
        var intervals: [ScheduleInterval] = []
        var start = 0
        for m in 1...1440 where m == 1440 || state[m] != state[start] {
            intervals.append(.init(start: start, end: m, state: state[start]))
            start = m
        }
        return DaySchedule(dateKey: dateKey, subgroup: subgroup, kind: .published,
                           intervals: intervals, source: source, publishedAt: publishedAt)
    }

    static func unknown(dateKey: String, subgroup: Subgroup, kind: DayScheduleKind) -> DaySchedule {
        DaySchedule(dateKey: dateKey, subgroup: subgroup, kind: kind,
                    intervals: [.init(start: 0, end: 1440, state: .unknown)], source: nil, publishedAt: nil)
    }

    func state(atMinute minute: Int) -> PowerState {
        intervals.first(where: { $0.contains(minute) })?.state ?? .unknown
    }

    var outageIntervals: [ScheduleInterval] { intervals.filter { $0.state == .outage } }
}

/// Один опублікований допис із графіком ГПВ на конкретну добу.
struct PublishedSchedulePost: Codable, Equatable, Sendable {
    let dateKey: String
    let publishedAt: Date
    let sourceURL: URL
    let title: String
    /// Інтервали відключень по підчергах ("1.1" ...). Підчерг, яких немає в дописі, тут немає.
    let outages: [String: [MinuteRange]]
    /// Частини інтервалів, що переходять через північ (для НАСТУПНОЇ доби).
    let spillover: [String: [MinuteRange]]
    /// Проміжки з незрозумілим значенням у джерелі (лише API, NOL-15). nil у старому кеші.
    var unknown: [String: [MinuteRange]]? = nil
}

/// Усе, що застосунок знає про графіки; зберігається в кеші й читається віджетами.
struct ScheduleSnapshot: Codable, Equatable, Sendable {
    static let currentVersion = 1

    let version: Int
    /// Час останньої УСПІШНОЇ перевірки джерела.
    let fetchedAt: Date
    let posts: [String: PublishedSchedulePost]
    /// Доби, для яких допис знайдено, але розпізнати не вдалося.
    let problemDates: [String]

    init(fetchedAt: Date, posts: [String: PublishedSchedulePost], problemDates: [String] = []) {
        self.version = Self.currentVersion
        self.fetchedAt = fetchedAt
        self.posts = posts
        self.problemDates = problemDates
    }

    func schedule(for subgroup: Subgroup, dateKey: String) -> DaySchedule {
        if problemDates.contains(dateKey) {
            return .unknown(dateKey: dateKey, subgroup: subgroup, kind: .parseFailed)
        }
        guard let post = posts[dateKey] else {
            return .unknown(dateKey: dateKey, subgroup: subgroup, kind: .notPublished)
        }
        let previousKey = KyivTime.addingDays(-1, to: dateKey)
        let carry = posts[previousKey]?.spillover[subgroup.id] ?? []
        let own = post.outages[subgroup.id]
        if own == nil && carry.isEmpty {
            return .unknown(dateKey: dateKey, subgroup: subgroup, kind: .subgroupNotListed)
        }
        return .build(dateKey: dateKey, subgroup: subgroup, outages: (own ?? []) + carry,
                      unknown: post.unknown?[subgroup.id] ?? [],
                      source: post.sourceURL, publishedAt: post.publishedAt)
    }
}

enum ScheduleError: Error, Equatable, Sendable {
    case offline
    case serverUnavailable(status: Int?)
    case structureChanged
    case parsingFailed(String)
    case invalidData(String)

    var message: String {
        switch self {
        case .offline: return "Немає підключення до інтернету."
        case .serverUnavailable: return "Сайт Черкасиобленерго недоступний."
        case .structureChanged: return "Структура сайту змінилася, графіки не вдалося прочитати."
        case .parsingFailed: return "Не вдалося розпізнати опублікований графік."
        case .invalidData: return "Опублікований графік містить некоректні дані."
        }
    }
}

extension ScheduleError: LocalizedError {
    var errorDescription: String? { message }
}
