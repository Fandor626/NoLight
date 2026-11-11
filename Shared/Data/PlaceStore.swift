import Foundation

/// Міграція v1 → місця: обрані підчерги стають місцями.
enum PlaceMigration {
    static let homeName = "Дім"

    /// Перша підчерга → «Дім», кожна наступна → «Підчерга X.Y». Порядок зберігається.
    static func places(fromV1 subgroups: [Subgroup], makeID: () -> UUID = { UUID() }) -> [Place] {
        var seen = Set<Subgroup>()
        let unique = subgroups.filter { seen.insert($0).inserted }
        return unique.enumerated().map { index, subgroup in
            Place(id: makeID(),
                  name: index == 0 ? homeName : Place.defaultName(for: subgroup),
                  region: .cherkasy,
                  subgroup: subgroup,
                  source: .oblenergoSite)
        }
    }
}

/// Збережені місця (впорядкований список) у UserDefaults App Group — спільні для застосунку й віджетів.
final class PlaceStore: @unchecked Sendable {
    private let defaults: UserDefaults
    static let placesKey = "places.v1"
    static let migratedKey = "placesMigrated.v1"

    init(defaults: UserDefaults) { self.defaults = defaults }

    static let shared = PlaceStore(defaults: UserDefaults(suiteName: AppConfig.appGroupID) ?? .standard)

    /// Пошкоджені дані читаються як порожній список (не падаємо).
    var places: [Place] {
        get {
            guard let data = defaults.data(forKey: Self.placesKey),
                  let list = try? JSONDecoder().decode([Place].self, from: data) else { return [] }
            return list
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) { defaults.set(data, forKey: Self.placesKey) }
        }
    }

    var isMigrated: Bool { defaults.bool(forKey: Self.migratedKey) }

    /// Одноразово переносить вибір v1 у місця. Ключ v1 не змінюється (можливість відкату).
    /// Якщо місця вже є (наприклад, міграцію виконала інша копія застосунку), нічого не перезаписує.
    @discardableResult
    func migrateFromV1IfNeeded(v1Subgroups: [Subgroup], makeID: () -> UUID = { UUID() }) -> Bool {
        guard !isMigrated else { return false }
        defer { defaults.set(true, forKey: Self.migratedKey) }
        guard places.isEmpty, !v1Subgroups.isEmpty else { return false }
        places = PlaceMigration.places(fromV1: v1Subgroups, makeID: makeID)
        return true
    }
}
