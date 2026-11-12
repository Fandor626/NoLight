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

    static func perform() async {
        let repository = ScheduleRepository.live(onUpdate: { WidgetCenter.shared.reloadAllTimelines() })
        _ = try? await repository.refresh()
        schedule()
    }
}
