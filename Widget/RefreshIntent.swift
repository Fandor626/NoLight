import AppIntents
import WidgetKit

/// Кнопка «Оновити» у віджеті. Виконується в процесі розширення віджета без відкриття застосунку.
/// Якщо оновити не вдалося (немає мережі, сайт недоступний), кеш лишається недоторканим,
/// а віджет і далі показує час останнього УСПІШНОГО оновлення та попередження про застарілість.
struct RefreshScheduleIntent: AppIntent {
    static var title: LocalizedStringResource = "Оновити графіки"
    static var description = IntentDescription("Завантажує актуальні графіки відключень.")
    static var isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        _ = try? await ScheduleRepository.live().refresh()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
