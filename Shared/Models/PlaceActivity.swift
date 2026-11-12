import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Live Activity «Відлік до зміни» (NOL-39): статичні дані — місце; динамічні — стан і час наступної зміни.
struct PlaceActivityContent: Codable, Hashable, Sendable {
    var state: PowerState
    var changeAt: Date?
    var nextState: PowerState?
    /// Коли активність запущено — для обмеження в 8 год.
    var startedAt: Date
    /// Коли дані графіка востаннє оновлено.
    var updatedAt: Date?
}

#if canImport(ActivityKit)
struct PlaceActivityAttributes: ActivityAttributes {
    typealias ContentState = PlaceActivityContent

    let placeID: UUID
    let placeName: String
    let subgroupID: String
}
#endif

/// Логіка Live Activity без ActivityKit (тестується окремо).
enum PlaceActivityPlanner {
    /// iOS завершує Live Activity через 8 год.
    static let maxDuration: TimeInterval = 8 * 3600

    static func content(presentation p: SubgroupPresentation, startedAt: Date) -> PlaceActivityContent {
        PlaceActivityContent(state: p.status.state, changeAt: p.status.changeAt, nextState: p.status.nextState,
                             startedAt: startedAt, updatedAt: p.lastCheck)
    }

    static func endDate(startedAt: Date) -> Date { startedAt.addingTimeInterval(maxDuration) }

    /// Після цього моменту вміст застарілий: настала зміна або минуло 8 год.
    static func staleDate(_ c: PlaceActivityContent) -> Date {
        let end = endDate(startedAt: c.startedAt)
        guard let change = c.changeAt else { return end }
        return min(change, end)
    }

    static func isExpired(startedAt: Date, now: Date) -> Bool { now >= endDate(startedAt: startedAt) }

    /// Великий заголовок на заблокованому екрані.
    static func headline(_ c: PlaceActivityContent) -> String {
        switch c.state {
        case .available: return "Світло є"
        case .outage: return "Світла немає"
        case .unknown: return "Невідомо"
        }
    }

    /// Підпис над таймером: до чого йде відлік.
    static func countdownTitle(_ c: PlaceActivityContent) -> String? {
        guard c.changeAt != nil else { return nil }
        switch (c.state, c.nextState) {
        case (.available, .some(.outage)): return "До відключення"
        case (.outage, .some(.available)): return "До появи світла"
        default: return "До кінця відомого графіка"
        }
    }

    /// Текст, коли відліку немає або він застарів.
    static func fallbackText(_ c: PlaceActivityContent, isStale: Bool, now: Date) -> String {
        if isExpired(startedAt: c.startedAt, now: now) { return "Відлік завершено. Натисніть, щоб запустити знову." }
        if isStale { return "Відкрийте застосунок, щоб оновити відлік." }
        switch c.state {
        case .available: return "Відключень не заплановано"
        case .outage: return "Час появи світла невідомий"
        case .unknown: return "Графік невідомий"
        }
    }
}
