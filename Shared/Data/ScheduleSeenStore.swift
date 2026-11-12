import Foundation

/// Останні побачені графіки місць (App Group), щоб помічати зміни незалежно від того,
/// хто оновив дані — застосунок, віджет чи фонове завдання (NOL-23).
final class ScheduleSeenStore: @unchecked Sendable {
    private let defaults: UserDefaults
    static let key = "scheduleSeen.v1"

    init(defaults: UserDefaults) { self.defaults = defaults }

    static let shared = ScheduleSeenStore(defaults: UserDefaults(suiteName: AppConfig.appGroupID) ?? .standard)

    var seen: SeenSchedules {
        get {
            guard let data = defaults.data(forKey: Self.key),
                  let value = try? JSONDecoder().decode(SeenSchedules.self, from: data) else { return [:] }
            return value
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) { defaults.set(data, forKey: Self.key) }
        }
    }
}
