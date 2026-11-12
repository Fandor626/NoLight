import Foundation

/// Режим оновлення графіків (NOL-19).
enum RefreshMode: String, CaseIterable, Sendable {
    case automatic, manual

    /// Віджети оновлюють дані самі лише в автоматичному режимі (NOL-42).
    var allowsWidgetSelfRefresh: Bool { self == .automatic }

    var title: String {
        switch self {
        case .automatic: return "Автоматично"
        case .manual: return "Лише вручну"
        }
    }
}

/// Інтервал автооновлення: лише пресети, мінімум 15 хв (PRD FR-17).
enum RefreshInterval: Int, CaseIterable, Sendable {
    case min15 = 15, min30 = 30, hour1 = 60, hour3 = 180, hour6 = 360

    static let `default` = RefreshInterval.min30
    static let minimum = RefreshInterval.min15

    var seconds: TimeInterval { TimeInterval(rawValue * 60) }

    var title: String {
        rawValue < 60 ? "\(rawValue) хв" : "\(rawValue / 60) год"
    }
}

/// Налаштування оновлення в App Group (спільні для застосунку й фонового завдання).
/// Пояснення біля інтервалу: iOS не гарантує точний час фонового оновлення (PRD FR-18).
enum RefreshCopy {
    static let intervalNote = "Це побажання, а не розклад: iOS сама вирішує, коли запускати фонове оновлення, тож воно може статися пізніше або рідше."
}

final class RefreshSettingsStore: @unchecked Sendable {
    private let defaults: UserDefaults
    static let modeKey = "refreshMode.v1"
    static let intervalKey = "refreshIntervalMinutes.v1"

    init(defaults: UserDefaults) { self.defaults = defaults }

    static let shared = RefreshSettingsStore(defaults: UserDefaults(suiteName: AppConfig.appGroupID) ?? .standard)

    /// За замовчуванням — автоматично (як у v1).
    var mode: RefreshMode {
        get { defaults.string(forKey: Self.modeKey).flatMap(RefreshMode.init(rawValue:)) ?? .automatic }
        set { defaults.set(newValue.rawValue, forKey: Self.modeKey) }
    }

    /// Невідоме або замале значення → 30 хв за замовчуванням.
    var interval: RefreshInterval {
        get { RefreshInterval(rawValue: defaults.integer(forKey: Self.intervalKey)) ?? .default }
        set { defaults.set(newValue.rawValue, forKey: Self.intervalKey) }
    }

    /// Чи можна оновлювати дані у фоновому завданні (NOL-20): лише в автоматичному режимі.
    var allowsBackgroundRefresh: Bool { mode == .automatic }

    /// Чи можуть віджети самі ходити в мережу (NOL-42): лише в автоматичному режимі.
    /// Кнопка «Оновити» у віджеті — дія користувача, працює в будь-якому режимі.
    var allowsWidgetSelfRefresh: Bool { mode.allowsWidgetSelfRefresh }

    /// Коли найраніше запускати наступне фонове оновлення; nil — у ручному режимі (не реєструвати).
    func nextBackgroundRefresh(after now: Date) -> Date? {
        mode == .manual ? nil : now.addingTimeInterval(interval.seconds)
    }
}
