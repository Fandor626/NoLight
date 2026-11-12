import SwiftUI
import WidgetKit

/// Віджет «Мої місця»: кілька карток місць у порядку застосунку (NOL-40).
struct PlacesListEntry: TimelineEntry {
    struct Item: Identifiable {
        let place: Place
        let presentation: SubgroupPresentation
        var id: UUID { place.id }
    }

    let date: Date
    /// Усі місця в порядку застосунку; скільки показати, вирішує розмір віджета.
    let places: [Place]
    let snapshot: ScheduleSnapshot?
    var refreshFailed = false
    var isPlaceholder = false

    func items(capacity: Int) -> (shown: [Item], overflow: Int) {
        let visible = PlacesListLayout.visible(places, capacity: capacity)
        let items = visible.shown.map {
            Item(place: $0, presentation: SubgroupPresentation(snapshot: snapshot, subgroup: $0.subgroup, now: date))
        }
        return (items, visible.overflow)
    }
}

struct PlacesListProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlacesListEntry {
        let sample = [Place(name: "Дім", subgroup: Subgroup(queue: 1, sub: 1)!),
                      Place(name: "Робота", subgroup: Subgroup(queue: 2, sub: 1)!)]
        return PlacesListEntry(date: .now, places: sample, snapshot: nil, isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (PlacesListEntry) -> Void) {
        Task {
            let snapshot = await ScheduleRepository.live().cachedSnapshot()
            completion(entry(date: .now, snapshot: snapshot))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PlacesListEntry>) -> Void) {
        Task {
            let snapshot = await ScheduleRepository.live().refreshIfNeeded(maxAge: 15 * 60)
            let now = Date()
            let shown = PlacesListLayout.visible(PlaceStore.shared.places, capacity: PlacesListLayout.largeCapacity).shown
            var dates = Set<Date>([now])
            for place in shown {
                dates.formUnion(WidgetTimelinePlanner.entryDates(now: now, snapshot: snapshot, subgroup: place.subgroup))
            }
            let entries = dates.sorted().map { entry(date: $0, snapshot: snapshot) }
            completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(30 * 60))))
        }
    }

    private func entry(date: Date, snapshot: ScheduleSnapshot?) -> PlacesListEntry {
        let failure = RefreshStatusStore.shared.lastFailure
        return PlacesListEntry(date: date, places: PlaceStore.shared.places, snapshot: snapshot,
                               refreshFailed: failure?.isNewer(than: snapshot?.fetchedAt) ?? false)
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
                                             style: .listRow, refreshFailed: entry.refreshFailed)
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
