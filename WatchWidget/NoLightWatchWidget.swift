import SwiftUI
import WidgetKit

@main
struct NoLightWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        WatchPlaceWidget()
    }
}

struct WatchPlaceEntry: TimelineEntry {
    let date: Date
    let place: Place?
    let snapshot: ScheduleSnapshot?
    let relevance: TimelineEntryRelevance?

    var presentation: SubgroupPresentation? {
        place.map { SubgroupPresentation(snapshot: snapshot, subgroup: $0.subgroup, now: date) }
    }

    var window: TimelineWindowData? {
        place.map { TimelineWindow.make(snapshot: snapshot, subgroup: $0.subgroup, now: date) }
    }
}

/// Віджет годинника (NOL-47): вибране на годиннику місце з App Group годинника.
struct WatchPlaceProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchPlaceEntry {
        WatchPlaceEntry(date: .now, place: Place(name: "Дім", subgroup: Subgroup(queue: 1, sub: 1)!),
                        snapshot: nil, relevance: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchPlaceEntry) -> Void) {
        Task {
            let (place, snapshot) = await load(refresh: false)
            completion(WatchPlaceEntry(date: .now, place: place, snapshot: snapshot, relevance: nil))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchPlaceEntry>) -> Void) {
        Task {
            let (place, snapshot) = await load(refresh: true)
            let now = Date()
            guard let place else {
                completion(Timeline(entries: [WatchPlaceEntry(date: now, place: nil, snapshot: nil, relevance: nil)],
                                    policy: .never))
                return
            }
            // Шкала «±2 год» зсувається з часом — записи кожні 15 хв + у моменти змін (на 6 год уперед).
            let dates = WidgetTimelinePlanner.entryDates(now: now, snapshot: snapshot, subgroup: place.subgroup,
                                                         horizon: 6 * 3600)
                .filter { $0 <= now.addingTimeInterval(6 * 3600) }
            let entries = dates.map { date -> WatchPlaceEntry in
                let status = SubgroupPresentation(snapshot: snapshot, subgroup: place.subgroup, now: date).status
                let score = WatchComplication.relevance(changeAt: status.changeAt, now: date)
                return WatchPlaceEntry(date: date, place: place, snapshot: snapshot,
                                       relevance: TimelineEntryRelevance(score: Float(score)))
            }
            completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(60 * 60))))
        }
    }

    private func load(refresh: Bool) async -> (Place?, ScheduleSnapshot?) {
        let places = PlaceStore.shared.places
        guard let id = WatchPlaceStore.resolve(chosen: WatchPlaceStore.shared.placeID, places: places),
              let place = places.first(where: { $0.id == id }) else { return (nil, nil) }
        let repo = ScheduleRepository.live(for: place.sourceKey)
        let snapshot = refresh ? await repo.refreshIfNeeded(maxAge: 30 * 60) : await repo.cachedSnapshot()
        return (place, snapshot)
    }
}

struct WatchPlaceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NoLightWatchPlace", provider: WatchPlaceProvider()) { entry in
            WatchPlaceWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("NoLight")
        .description("Місце з годинника: стан, відлік і графік на ±2 години.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline, .accessoryCorner])
    }
}

struct WatchPlaceWidgetView: View {
    let entry: WatchPlaceEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let place = entry.place, let p = entry.presentation, let window = entry.window {
            switch family {
            case .accessoryRectangular: rectangular(place: place, p: p, window: window)
            case .accessoryCircular: circular(p: p)
            case .accessoryCorner: corner(p: p)
            default: Text(WatchComplication.inline(p.status, now: entry.date))
            }
        } else {
            switch family {
            case .accessoryInline: Text("NoLight: додайте місце")
            case .accessoryCircular, .accessoryCorner: Image(systemName: "bolt.slash")
            default:
                VStack(alignment: .leading) {
                    Text("NoLight").font(.headline)
                    Text("Додайте місце на iPhone").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Smart Stack і циферблати: назва, стан, шкала −2 … +2 год і відлік.
    private func rectangular(place: Place, p: SubgroupPresentation, window: TimelineWindowData) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(place.name).font(.caption2.weight(.semibold)).lineLimit(1)
                Spacer(minLength: 2)
                Text(p.status.state.watchHeadline)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(p.status.state.watchColor)
                    .widgetAccentable()
            }
            WatchTimelineBar(window: window, height: 7, showsLabels: false)
                .widgetAccentable()
            if let at = p.status.changeAt, at > entry.date, let title = WatchCopy.countdownTitle(p.status) {
                HStack(spacing: 4) {
                    Text(title).foregroundStyle(.secondary)
                    Spacer(minLength: 2)
                    Text(timerInterval: entry.date...at, countsDown: true, showsHours: true)
                        .monospacedDigit().multilineTextAlignment(.trailing)
                }
                .font(.caption2)
            } else {
                Text(p.showsExpiredWarning ? "Дані застаріли" : (p.detail ?? "Графік невідомий"))
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }

    /// Кільце: скільки минуло з поточного проміжку до зміни; у центрі — значок стану.
    private func circular(p: SubgroupPresentation) -> some View {
        let progress = WatchComplication.progress(today: p.today, tomorrow: p.tomorrow, now: entry.date) ?? 0
        return Gauge(value: progress) {
            Image(systemName: "bolt.fill")
        } currentValueLabel: {
            Image(systemName: p.status.state == .outage ? "bolt.slash.fill" : (p.status.state == .available ? "bolt.fill" : "questionmark"))
                .foregroundStyle(p.status.state.watchColor)
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(p.status.state.watchColor)
        .widgetAccentable()
    }

    private func corner(p: SubgroupPresentation) -> some View {
        Image(systemName: p.status.state == .outage ? "bolt.slash.fill" : "bolt.fill")
            .font(.title3)
            .foregroundStyle(p.status.state.watchColor)
            .widgetLabel {
                if let at = p.status.changeAt, at > entry.date {
                    Text(timerInterval: entry.date...at, countsDown: true)
                } else {
                    Text(p.status.state.watchHeadline)
                }
            }
    }
}
