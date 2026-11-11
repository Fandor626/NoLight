import BackgroundTasks
import WidgetKit

/// iOS сама вирішує, коли (і чи) запускати фонове оновлення — гарантій щодо часу немає.
/// Тому дані оновлюються також при відкритті застосунку, вручну та самими віджетами.
enum BackgroundRefresh {
    static var identifier: String { (Bundle.main.bundleIdentifier ?? "com.example.NoLight") + ".refresh" }

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    static func perform() async {
        let repository = ScheduleRepository.live(onUpdate: { WidgetCenter.shared.reloadAllTimelines() })
        _ = try? await repository.refresh()
        schedule()
    }
}
