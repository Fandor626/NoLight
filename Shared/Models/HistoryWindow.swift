import Foundation

/// Дні, які можна переглянути в деталях місця: останні `AppConfig.historyDays` днів, сьогодні й завтра.
enum HistoryWindow {
    /// Найстаріший день, що ще зберігається в кеші.
    static func oldestKey(today: String, days: Int = AppConfig.historyDays) -> String {
        KyivTime.addingDays(-days, to: today)
    }

    /// Попередні дні від учора до найстарішого (новіші спочатку).
    static func previousKeys(today: String, days: Int = AppConfig.historyDays) -> [String] {
        (1...max(days, 1)).map { KyivTime.addingDays(-$0, to: today) }
    }

    /// Графік минулого дня: якщо допису немає — «невідомо», а не «ще не опубліковано».
    static func pastSchedule(snapshot: ScheduleSnapshot?, subgroup: Subgroup, dateKey: String) -> DaySchedule {
        guard let snapshot else { return .unknown(dateKey: dateKey, subgroup: subgroup, kind: .noData) }
        let day = snapshot.schedule(for: subgroup, dateKey: dateKey)
        return day.kind == .notPublished ? .unknown(dateKey: dateKey, subgroup: subgroup, kind: .noData) : day
    }

    static let unknownTitle = "Невідомо"
    static let unknownMessage = "Для цього дня немає збереженого графіка."
}
