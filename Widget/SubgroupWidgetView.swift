import SwiftUI
import WidgetKit

/// Маленька кнопка оновлення (iOS 17+ Button(intent:)).
struct RefreshButton: View {
    var body: some View {
        Button(intent: RefreshScheduleIntent()) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .background(Color.secondary.opacity(0.15), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Оновити графіки")
    }
}

struct SubgroupWidgetView: View {
    let entry: SubgroupEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let p = entry.presentation
        Group {
            if entry.isPlaceDeleted {
                DeletedPlaceView()
            } else {
                switch family {
                case .systemSmall:
                    PlaceCardContent(name: entry.title, presentation: p, style: .widgetSmall,
                                     refreshFailed: entry.refreshFailed, isUnofficial: entry.isUnofficial) { RefreshButton() }
                case .systemMedium:
                    PlaceCardContent(name: entry.title, presentation: p, style: .widgetMedium,
                                     refreshFailed: entry.refreshFailed, isUnofficial: entry.isUnofficial) { RefreshButton() }
                default:
                    VStack(alignment: .leading, spacing: 10) {
                        PlaceCardContent(name: entry.title, presentation: p, style: .widgetLarge,
                                         refreshFailed: entry.refreshFailed, isUnofficial: entry.isUnofficial) { RefreshButton() }
                        LargeExtras(p: p)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .redacted(reason: entry.isPlaceholder ? .placeholder : [])
        .containerBackground(.background, for: .widget)
        .widgetURL(entry.placeID.map(DeepLink.place) ?? DeepLink.home)
    }
}

/// Вибране місце видалено в застосунку.
private struct DeletedPlaceView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "mappin.slash").font(.title3).foregroundStyle(.secondary)
            Text("Місце видалено, оберіть інше")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
            Text("Утримуйте віджет → «Змінити віджет».").font(.caption2).foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Додатково у великому віджеті: завтра й список відключень на сьогодні.
private struct LargeExtras: View {
    let p: SubgroupPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Завтра").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            if let title = p.tomorrow.kind.placeholderTitle {
                Text(title).font(.caption).foregroundStyle(.secondary)
            } else {
                TimelineBarView(intervals: p.tomorrow.intervals, nowMinute: nil, barHeight: 14, hourLabels: [])
            }
            let outages = p.today.outageIntervals
            if p.today.kind == .published, !outages.isEmpty {
                Text("Відключення сьогодні").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 3) {
                    ForEach(Array(outages.prefix(8).enumerated()), id: \.offset) { _, i in
                        Text("\(KyivTime.minuteString(i.start)) – \(KyivTime.minuteString(i.end))")
                            .font(.caption).monospacedDigit()
                    }
                }
            }
        }
    }
}
