import SwiftUI
import WidgetKit

struct SubgroupEntry: TimelineEntry {
    let date: Date
    let presentation: SubgroupPresentation
    var isPlaceholder = false
}

struct SubgroupProvider: AppIntentTimelineProvider {
    typealias Intent = SelectSubgroupIntent
    typealias Entry = SubgroupEntry

    func placeholder(in context: TimelineProviderContext) -> SubgroupEntry {
        let sg = Subgroup(queue: 1, sub: 1)!
        return SubgroupEntry(date: .now, presentation: SubgroupPresentation(snapshot: nil, subgroup: sg, now: .now),
                             isPlaceholder: true)
    }

    func snapshot(for configuration: SelectSubgroupIntent, in context: TimelineProviderContext) async -> SubgroupEntry {
        let snapshot = await ScheduleRepository.live().cachedSnapshot()
        let sg = configuration.subgroup.subgroup
        return SubgroupEntry(date: .now, presentation: SubgroupPresentation(snapshot: snapshot, subgroup: sg, now: .now))
    }

    func timeline(for configuration: SelectSubgroupIntent, in context: TimelineProviderContext) async -> Timeline<SubgroupEntry> {
        // Віджет сам пробує оновити дані; при невдачі використовується кеш.
        let snapshot = await ScheduleRepository.live().refreshIfNeeded(maxAge: 15 * 60)
        let now = Date()
        let sg = configuration.subgroup.subgroup
        let dates = WidgetTimelinePlanner.entryDates(now: now, snapshot: snapshot, subgroup: sg)
        let entries = dates.map {
            SubgroupEntry(date: $0, presentation: SubgroupPresentation(snapshot: snapshot, subgroup: sg, now: $0))
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
        .configurationDisplayName("Графік відключень")
        .description("Графік відключень електроенергії для обраної підчерги.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct CherkasyLightWidgetBundle: WidgetBundle {
    var body: some Widget { SubgroupScheduleWidget() }
}
