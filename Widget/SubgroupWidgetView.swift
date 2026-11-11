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
            switch family {
            case .systemSmall: SmallWidgetView(p: p)
            case .systemMedium: MediumWidgetView(p: p)
            default: LargeWidgetView(p: p)
            }
        }
        .redacted(reason: entry.isPlaceholder ? .placeholder : [])
        .containerBackground(.background, for: .widget)
    }
}

private struct SmallWidgetView: View {
    let p: SubgroupPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                SubgroupBadge(text: p.subgroup.id, compact: true)
                Spacer()
                if p.showsStaleWarning {
                    Image(systemName: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.orange)
                }
                RefreshButton()
            }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                SubgroupBadge(text: p.subgroup.id)
                VStack(alignment: .leading, spacing: 1) {
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
                if p.showsStaleWarning {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                SubgroupBadge(text: p.subgroup.id)
                VStack(alignment: .leading, spacing: 1) {
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
                if p.showsStaleWarning {
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
