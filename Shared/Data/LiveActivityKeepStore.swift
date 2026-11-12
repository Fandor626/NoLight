import Foundation

/// Місця, для яких відлік має бути «завжди на екрані» (NOL-43): поки користувач не зупинить його в застосунку.
final class LiveActivityKeepStore: @unchecked Sendable {
    private let defaults: UserDefaults
    static let key = "liveActivityKept.v1"

    init(defaults: UserDefaults) { self.defaults = defaults }

    static let shared = LiveActivityKeepStore(defaults: UserDefaults(suiteName: AppConfig.appGroupID) ?? .standard)

    var placeIDs: Set<UUID> {
        get { Set((defaults.stringArray(forKey: Self.key) ?? []).compactMap(UUID.init(uuidString:))) }
        set { defaults.set(newValue.map(\.uuidString).sorted(), forKey: Self.key) }
    }

    func contains(_ id: UUID) -> Bool { placeIDs.contains(id) }
    func add(_ id: UUID) { placeIDs.insert(id) }
    func remove(_ id: UUID) { placeIDs.remove(id) }
}
