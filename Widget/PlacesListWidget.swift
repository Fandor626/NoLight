import SwiftUI
import WidgetKit

/// Віджет «Мої місця»: кілька карток місць у порядку застосунку (NOL-40).
struct PlacesListEntry: TimelineEntry {
    struct Item: Identifiable {
        let place: Place
        let presentation: SubgroupPresentation
        let refreshFailed: Bool
        var id: UUID { place.id }
    }

    let date: Date
    /// Усі місця в порядку застосунку; скільки показати, вирішує розмір віджета.
    let places: [Place]
    /// Дані кожного джерела й області (NOL-15).
    let snapshots: [ScheduleSourceKey: ScheduleSnapshot]
    /// Джерела, останнє оновлення яких не вдалося (після останнього успішного).
    var failedKeys: Set<ScheduleSourceKey> = []
    var isPlaceholder = false

    func items(capacity: Int) -> (shown: [Item], overflow: Int) {
        let visible = PlacesListLayout.visible(places, capacity: capacity)
        let items = visible.shown.map {
            Item(place: $0,
                 presentation: SubgroupPresentation(snapshot: snapshots[$0.sourceKey], subgroup: $0.subgroup, now: date),
                 refreshFailed: failedKeys.contains($0.sourceKey))
        }
        return (items, visible.overflow)
    }
}

struct PlacesListProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlacesListEntry {
        let sample = [Place(name: "Дім", subgroup: Subgroup(queue: 1, sub: 1)!),
                      Place(name: "Робота", subgroup: Subgroup(queue: 2, sub: 1)!)]
        return PlacesListEntry(date: .now, places: sample, snapshots: [:], isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (PlacesListEntry) -> Void) {
        Task {
            let data = await load(refresh: false)
            completion(entry(date: .now, data: data))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PlacesListEntry>) -> Void) {
        Task {
            let data = await load(refresh: true)
            let now = Date()
            let shown = PlacesListLayout.visible(PlaceStore.shared.places, capacity: PlacesListLayout.largeCapacity).shown
            var dates = Set<Date>([now])
            for place in shown {
                dates.formUnion(WidgetTimelinePlanner.entryDates(now: now, snapshot: data[place.sourceKey],
                                                                 subgroup: place.subgroup))
            }
            let entries = dates.sorted().map { entry(date: $0, data: data) }
            completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(30 * 60))))
        }
    }

    /// Кеш (або оновлення, якщо кеш старіший за 15 хв) для кожного джерела, яке використовують місця.
    private func load(refresh: Bool) async -> [ScheduleSourceKey: ScheduleSnapshot] {
        var out: [ScheduleSourceKey: ScheduleSnapshot] = [:]
        for key in ScheduleSourceKey.active(for: PlaceStore.shared.places) {
            let repo = ScheduleRepository.live(for: key)
            if refresh {
                out[key] = await repo.refreshIfNeeded(maxAge: 15 * 60)
            } else {
                out[key] = await repo.cachedSnapshot()
            }
        }
        return out
    }

    private func entry(date: Date, data: [ScheduleSourceKey: ScheduleSnapshot]) -> PlacesListEntry {
        let failed = Set(ScheduleSourceKey.active(for: PlaceStore.shared.places).filter { key in
            RefreshStatusStore.shared(for: key).lastFailure?.isNewer(than: data[key]?.fetchedAt) ?? false
        })
        return PlacesListEntry(date: date, places: PlaceStore.shared.places, snapshots: data, failedKeys: failed)
    }
}

struct PlacesListWidgetView: View {
    let entry: PlacesListEntry
    @Environment(\.widgetFamily) private var family

    private var capacity: Int {
        family == .systemLarge ? PlacesListLayout.largeCapacity : PlacesListLayout.mediumCapacity
    }

    var body: some View {
        let visible = entry.items(capacity: capacity)
        let items = visible.shown
        Group {
            if items.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: "mappin.and.ellipse").font(.title3).foregroundStyle(.secondary)
                    Text("Додайте місце в застосунку")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: family == .systemLarge ? 12 : 8) {
                    ForEach(items) { item in
                        Link(destination: DeepLink.place(item.id)) {
                            PlaceCardContent(name: item.place.name, presentation: item.presentation,
                                             style: .listRow, refreshFailed: item.refreshFailed)
                        }
                    }
                    Spacer(minLength: 0)
                    HStack {
                        if let more = PlacesListLayout.overflowText(visible.overflow) {
                            Text(more).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let updated = items.first?.presentation.updatedText {
                            Text(updated).foregroundStyle(.secondary)
                        }
                        RefreshButton()
                    }
                    .font(.caption2)
                }
            }
        }
        .redacted(reason: entry.isPlaceholder ? .placeholder : [])
        .containerBackground(.background, for: .widget)
        .widgetURL(DeepLink.home)
    }
}

struct PlacesListWidget: Widget {
    let kind = "PlacesListWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlacesListProvider()) { entry in
            PlacesListWidgetView(entry: entry)
        }
        .configurationDisplayName("Мої місця")
        .description("Кілька ваших місць, як на головному екрані застосунку.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
