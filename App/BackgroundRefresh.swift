import BackgroundTasks
import WidgetKit

/// iOS сама вирішує, коли (і чи) запускати фонове оновлення — гарантій щодо часу немає.
/// Тому дані оновлюються також при відкритті застосунку, вручну та самими віджетами.
enum BackgroundRefresh {
    static var identifier: String { (Bundle.main.bundleIdentifier ?? "com.example.NoLight") + ".refresh" }

    /// Реєструє наступне фонове оновлення за налаштуваннями (NOL-19); у ручному режимі скасовує його.
    static func schedule(settings: RefreshSettingsStore = .shared) {
        guard let earliest = settings.nextBackgroundRefresh(after: Date()) else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
            return
        }
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = earliest
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Фонове завдання iOS (NOL-20). Одне оновлення джерела оновлює графіки всіх місць (дані спільні для всіх підчерг);
    /// після успіху віджети перезавантажуються (`onUpdate`). Помилка не змінює кеш — її записує `ScheduleRepository`.
    static func perform(settings: RefreshSettingsStore = .shared) async {
        defer { schedule(settings: settings) }
        // Запит міг лишитися з автоматичного режиму: у ручному нічого не оновлюємо.
        guard settings.allowsBackgroundRefresh else { return }
        // Усі джерела й області, що використовують місця (NOL-15); помилка одного не зупиняє інші.
        await withTaskGroup(of: Void.self) { group in
            for key in ScheduleSourceKey.active(for: PlaceStore.shared.places) {
                group.addTask {
                    _ = try? await ScheduleRepository.live(for: key, onUpdate: { WidgetCenter.shared.reloadAllTimelines() })
                        .refresh()
                }
            }
        }
        // Після оновлення — сповіщення про зміни графіка (NOL-23) і перепланування попереджень (NOL-21).
        await ScheduleChangeNotifier.processFromStores()
        await NotificationScheduler.replanFromStores()
        await LiveActivityManager.updateFromStores()
    }
}
