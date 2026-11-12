import SwiftUI
import WidgetKit

/// Маленька кнопка оновлення (iOS 17+ Button(intent:)).
private struct RefreshButton: View {
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
                case .systemSmall: SmallWidgetView(p: p, title: entry.title, refreshFailed: entry.refreshFailed)
                case .systemMedium: MediumWidgetView(p: p, title: entry.title, refreshFailed: entry.refreshFailed)
                default: LargeWidgetView(p: p, title: entry.title, refreshFailed: entry.refreshFailed)
                }
            }
        }
        .redacted(reason: entry.isPlaceholder ? .placeholder : [])
        .containerBackground(.background, for: .widget)
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

/// Позначка «оновити не вдалося»: графік показується зі збереженого кешу.
private struct RefreshFailedLabel: View {
    var compact = false
    var body: some View {
        if compact {
            Image(systemName: "wifi.exclamationmark").font(.caption).foregroundStyle(.orange)
                .accessibilityLabel("Не вдалося оновити, показано збережений графік")
        } else {
            Label("Не вдалося оновити", systemImage: "wifi.exclamationmark").foregroundStyle(.orange)
        }
    }
}

/// Назва місця над станом.
private struct PlaceTitle: View {
    let title: String
    var body: some View {
        Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary).lineLimit(1)
    }
}

private struct SmallWidgetView: View {
    let p: SubgroupPresentation
    let title: String
    let refreshFailed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                SubgroupBadge(text: p.subgroup.id, compact: true)
                Spacer()
                if refreshFailed {
                    RefreshFailedLabel(compact: true)
                } else if p.showsStaleWarning {
                    Image(systemName: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.orange)
                        .accessibilityLabel("Дані можуть бути застарілими")
                }
                RefreshButton()
            }
            PlaceTitle(title: title)
            Text(p.headline)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(p.status.state.textColor)
                .lineLimit(2).minimumScaleFactor(0.7)
            if let detail = p.detail {
                Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 0)
            TimelineBarView(intervals: p.today.intervals, nowMinute: p.minuteNow,
                            barHeight: 10, hourLabels: [0, 6, 12, 18, 24], labelFontSize: 8)
        }
    }
}

private struct MediumWidgetView: View {
    let p: SubgroupPresentation
    let title: String
    let refreshFailed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                SubgroupBadge(text: p.subgroup.id)
                VStack(alignment: .leading, spacing: 1) {
                    PlaceTitle(title: title)
                    Text(p.headline)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(p.status.state.textColor)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    if let detail = p.detail {
                        Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
                    }
                }
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
            TimelineBarView(intervals: p.today.intervals, nowMinute: p.minuteNow, barHeight: 18,
                            hourLabels: [0, 3, 6, 9, 12, 15, 18, 21, 24])
            HStack {
                if refreshFailed {
                    RefreshFailedLabel()
                } else if p.showsStaleWarning {
                    Label("Дані можуть бути застарілими", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                } else if p.today.kind == .published {
                    Label("Відключення", systemImage: "circle.fill").foregroundStyle(PowerState.outage.color)
                }
                Spacer()
                if let updated = p.updatedText { Text(updated).foregroundStyle(.secondary) }
                RefreshButton()
            }
            .font(.caption2)
            .labelStyle(.titleAndIcon)
        }
    }
}

private struct LargeWidgetView: View {
    let p: SubgroupPresentation
    let title: String
    let refreshFailed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                SubgroupBadge(text: p.subgroup.id)
                VStack(alignment: .leading, spacing: 1) {
                    PlaceTitle(title: title)
                    Text(p.headline).font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(p.status.state.textColor).lineLimit(1).minimumScaleFactor(0.8)
                    if let detail = p.detail { Text(detail).font(.footnote).foregroundStyle(.secondary).lineLimit(1) }
                }
                Spacer(minLength: 0)
            }

            Text("Сьогодні").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            TimelineBarView(intervals: p.today.intervals, nowMinute: p.minuteNow, barHeight: 20,
                            hourLabels: [0, 3, 6, 9, 12, 15, 18, 21, 24])

            Text("Завтра").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            TimelineBarView(intervals: p.tomorrow.intervals, nowMinute: nil, barHeight: 14, hourLabels: [])

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
            Spacer(minLength: 0)
            HStack {
                if refreshFailed {
                    RefreshFailedLabel()
                } else if p.showsStaleWarning {
                    Label("Дані можуть бути застарілими", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                Spacer()
                if let updated = p.updatedText { Text(updated).foregroundStyle(.secondary) }
                RefreshButton()
            }
            .font(.caption2)
        }
    }
}
