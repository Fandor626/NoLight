import Foundation

/// Що iPhone передає на годинник через WatchConnectivity (NOL-46).
struct WatchPayload: Codable, Equatable, Sendable {
    var places: [Place]
    /// Місце, вибране на iPhone («Показувати на годиннику»); nil — не вибрано.
    var preferredPlaceID: UUID?
    var theme: ColorTheme
    var sentAt: Date

    static let contextKey = "payload"

    func applicationContext() throws -> [String: Any] {
        [Self.contextKey: try JSONEncoder().encode(self)]
    }

    static func decode(_ context: [String: Any]) -> WatchPayload? {
        guard let data = context[contextKey] as? Data else { return nil }
        return try? JSONDecoder().decode(WatchPayload.self, from: data)
    }
}

/// Місце для годинника (NOL-46) в App Group: на iPhone — що показувати на годиннику,
/// на годиннику — що вибрано зараз (бачить і віджет годинника).
final class WatchPlaceStore: @unchecked Sendable {
    private let defaults: UserDefaults
    static let key = "watchPlaceID.v1"
    static let lastPreferredKey = "watchLastPreferredPlaceID.v1"

    init(defaults: UserDefaults) { self.defaults = defaults }

    static let shared = WatchPlaceStore(defaults: UserDefaults(suiteName: AppConfig.appGroupID) ?? .standard)

    var placeID: UUID? {
        get { defaults.string(forKey: Self.key).flatMap(UUID.init(uuidString:)) }
        set { defaults.set(newValue?.uuidString, forKey: Self.key) }
    }

    /// Останній вибір, що прийшов з iPhone: новий вибір на iPhone перекриває вибір на годиннику.
    var lastPreferredID: UUID? {
        get { defaults.string(forKey: Self.lastPreferredKey).flatMap(UUID.init(uuidString:)) }
        set { defaults.set(newValue?.uuidString, forKey: Self.lastPreferredKey) }
    }

    /// Застосовує дані з iPhone і повертає місце, яке показувати.
    @discardableResult
    func apply(_ payload: WatchPayload) -> UUID? {
        if let preferred = payload.preferredPlaceID, preferred != lastPreferredID {
            placeID = preferred
        }
        lastPreferredID = payload.preferredPlaceID
        let chosen = Self.resolve(chosen: placeID, places: payload.places)
        placeID = chosen
        return chosen
    }

    /// Вибране місце, якщо воно ще існує; інакше перше.
    static func resolve(chosen: UUID?, places: [Place]) -> UUID? {
        if let chosen, places.contains(where: { $0.id == chosen }) { return chosen }
        return places.first?.id
    }
}
