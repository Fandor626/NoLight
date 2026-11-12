import Foundation

/// Історія змін графіка (NOL-24): чиста логіка + сховище в App Group.
enum ScheduleChangeHistory {
    /// Додає нові зміни, прибирає записи старші за `AppConfig.historyDays` і видалених місць; новіші — першими.
    static func merged(_ existing: [ScheduleChange], adding new: [ScheduleChange], placeIDs: Set<UUID>,
                       now: Date) -> [ScheduleChange] {
        let cutoff = now.addingTimeInterval(-TimeInterval(AppConfig.historyDays) * 24 * 3600)
        return (existing + new)
            .filter { $0.detectedAt >= cutoff && placeIDs.contains($0.placeID) }
            .sorted { $0.detectedAt > $1.detectedAt }
    }

    static func entries(for placeID: UUID, in all: [ScheduleChange]) -> [ScheduleChange] {
        all.filter { $0.placeID == placeID }
    }
}

final class ScheduleChangeHistoryStore: @unchecked Sendable {
    private let defaults: UserDefaults
    static let key = "scheduleChanges.v1"

    init(defaults: UserDefaults) { self.defaults = defaults }

    static let shared = ScheduleChangeHistoryStore(defaults: UserDefaults(suiteName: AppConfig.appGroupID) ?? .standard)

    var changes: [ScheduleChange] {
        get {
            guard let data = defaults.data(forKey: Self.key),
                  let value = try? JSONDecoder().decode([ScheduleChange].self, from: data) else { return [] }
            return value
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) { defaults.set(data, forKey: Self.key) }
        }
    }

    func record(_ new: [ScheduleChange], places: [Place], now: Date = Date()) {
        changes = ScheduleChangeHistory.merged(changes, adding: new, placeIDs: Set(places.map(\.id)), now: now)
    }
}
