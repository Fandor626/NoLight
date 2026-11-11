import Foundation

protocol ScheduleCaching: Sendable {
    func load() -> ScheduleSnapshot?
    func save(_ snapshot: ScheduleSnapshot) throws
}

/// JSON-файл у контейнері App Group (спільний для застосунку та віджетів).
struct FileScheduleCache: ScheduleCaching {
    let fileURL: URL

    static func appGroup() -> FileScheduleCache {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConfig.appGroupID)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return FileScheduleCache(fileURL: base.appendingPathComponent("schedule-cache-v\(ScheduleSnapshot.currentVersion).json"))
    }

    /// nil, якщо файлу немає, він пошкоджений або має іншу версію.
    func load() -> ScheduleSnapshot? {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(ScheduleSnapshot.self, from: data),
              snapshot.version == ScheduleSnapshot.currentVersion else { return nil }
        return snapshot
    }

    func save(_ snapshot: ScheduleSnapshot) throws {
        guard snapshot.version == ScheduleSnapshot.currentVersion else {
            throw ScheduleError.invalidData("Невідома версія кешу.")
        }
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(snapshot).write(to: fileURL, options: .atomic)
    }
}
