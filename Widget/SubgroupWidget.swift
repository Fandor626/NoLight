import SwiftUI
import WidgetKit

struct SubgroupEntry: TimelineEntry {
    let date: Date
    let presentation: SubgroupPresentation
    /// Назва місця (або «Підчерга X.Y» для віджетів v1 без місця).
    var title: String
    /// Вибране місце видалено в застосунку.
    var isPlaceDeleted = false
    /// Останнє оновлення не вдалося (після останнього успішного): показуємо збережений графік з позначкою.
    var refreshFailed = false
    var isPlaceholder = false

    static func make(date: Date, snapshot: ScheduleSnapshot?, resolution: WidgetPlaceResolution,
                     failure: RefreshFailure? = RefreshStatusStore.shared.lastFailure) -> SubgroupEntry {
        // Для видаленого місця підчерга не важлива: показується лише повідомлення.
        let subgroup = resolution.subgroup ?? Subgroup(queue: 1, sub: 1)!
        return SubgroupEntry(date: date,
                             presentation: SubgroupPresentation(snapshot: snapshot, subgroup: subgroup, now: date),
                             title: resolution.title,
                             isPlaceDeleted: resolution == .deleted,
                             refreshFailed: failure?.isNewer(than: snapshot?.fetchedAt) ?? false)
    }
}

struct SubgroupProvider: AppIntentTimelineProvider {
    typealias Intent = SelectSubgroupIntent
    typealias Entry = SubgroupEntry

    func placeholder(in context: TimelineProviderContext) -> SubgroupEntry {
        let sg = Subgroup(queue: 1, sub: 1)!
        return SubgroupEntry(date: .now, presentation: SubgroupPresentation(snapshot: nil, subgroup: sg, now: .now),
                             title: "Дім", isPlaceholder: true)
    }

    func snapshot(for configuration: SelectSubgroupIntent, in context: TimelineProviderContext) async -> SubgroupEntry {
        let snapshot = await ScheduleRepository.live().cachedSnapshot()
        return .make(date: .now, snapshot: snapshot, resolution: configuration.resolution)
    }

    func timeline(for configuration: SelectSubgroupIntent, in context: TimelineProviderContext) async -> Timeline<SubgroupEntry> {
        // Віджет сам пробує оновити дані; при невдачі використовується кеш.
        let snapshot = await ScheduleRepository.live().refreshIfNeeded(maxAge: 15 * 60)
        let now = Date()
        let resolution = configuration.resolution
        let failure = RefreshStatusStore.shared.lastFailure
        guard let sg = resolution.subgroup else {
            return Timeline(entries: [.make(date: now, snapshot: snapshot, resolution: resolution, failure: failure)],
                            policy: .never)
        }
        let dates = WidgetTimelinePlanner.entryDates(now: now, snapshot: snapshot, subgroup: sg)
        let entries = dates.map {
            SubgroupEntry.make(date: $0, snapshot: snapshot, resolution: resolution, failure: failure)
        }
        // WidgetKit сам вирішує, коли реально перезапустити провайдер; це лише побажання.
        return Timeline(entries: entries, policy: .after(now.addingTimeInterval(30 * 60)))
    }
}

struct SubgroupScheduleWidget: Widget {
    let kind = "SubgroupScheduleWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectSubgroupIntent.self, provider: SubgroupProvider()) { entry in
            SubgroupWidgetView(entry: entry)
        }
        .configurationDisplayName("Місце")
        .description("Графік відключень для одного з ваших місць.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct NoLightWidgetBundle: WidgetBundle {
    var body: some Widget { SubgroupScheduleWidget() }
}
