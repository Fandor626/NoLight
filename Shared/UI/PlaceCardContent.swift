import SwiftUI

/// Розмір картки місця: у застосунку, у віджетах і рядком у віджеті «Мої місця».
enum PlaceCardStyle: Sendable {
    case app, widgetSmall, widgetMedium, widgetLarge, listRow
}

/// Єдина картка місця для застосунку й віджетів (NOL-40): ті самі тексти, кольори й стани.
/// Стиль змінює лише розміри та те, що вміщується.
struct PlaceCardContent<Accessory: View>: View {
    let name: String
    let presentation: SubgroupPresentation
    var style: PlaceCardStyle = .app
    /// Останнє оновлення не вдалося: показано збережений графік.
    var refreshFailed = false
    @ViewBuilder var accessory: () -> Accessory

    private var p: SubgroupPresentation { presentation }

    var body: some View {
        switch style {
        case .widgetSmall: small
        case .listRow: row
        default: regular
        }
    }

    // MARK: - Layouts

    private var regular: some View {
        VStack(alignment: .leading, spacing: style == .app ? 12 : 8) {
            HStack(alignment: .center, spacing: 10) {
                SubgroupBadge(text: p.subgroup.id)
                VStack(alignment: .leading, spacing: 1) {
                    nameText
                    Text(p.headline)
                        .font(.system(style == .widgetLarge ? .title3 : .headline, design: .rounded,
                                      weight: style == .widgetLarge ? .bold : .semibold))
                        .foregroundStyle(p.status.state.textColor)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    if let detail = p.detail {
                        Text(detail).font(style == .app ? .subheadline : .caption)
                            .foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
                    }
                }
                Spacer(minLength: 0)
                accessory()
            }
            if style == .widgetMedium { Spacer(minLength: 0) }
            TimelineBarView(intervals: p.today.intervals, nowMinute: p.minuteNow,
                            barHeight: style == .app ? 16 : (style == .widgetLarge ? 20 : 18),
                            hourLabels: style == .app ? [0, 6, 12, 18, 24] : [0, 3, 6, 9, 12, 15, 18, 21, 24])
            footer
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                SubgroupBadge(text: p.subgroup.id, compact: true)
                Spacer()
                statusIcon
                accessory()
            }
            nameText
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

    /// Компактний рядок для віджета «Мої місця».
    private var row: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                SubgroupBadge(text: p.subgroup.id, compact: true)
                Text(name).font(.subheadline.weight(.semibold)).lineLimit(1)
                Spacer(minLength: 4)
                Text(p.headline)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(p.status.state.textColor)
                    .lineLimit(1).minimumScaleFactor(0.7)
                statusIcon
            }
            if let detail = p.detail {
                Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            TimelineBarView(intervals: p.today.intervals, nowMinute: p.minuteNow, barHeight: 8,
                            hourLabels: [], showsMarkerLabel: false)
        }
    }

    // MARK: - Parts

    private var nameText: some View {
        Text(name)
            .font(style == .app ? .subheadline.weight(.semibold) : .caption.weight(.semibold))
            .foregroundStyle(.secondary).lineLimit(1)
    }

    @ViewBuilder
    private var statusIcon: some View {
        if refreshFailed {
            Image(systemName: "wifi.exclamationmark").font(.caption).foregroundStyle(.orange)
                .accessibilityLabel("Не вдалося оновити, показано збережений графік")
        } else if p.showsStaleWarning {
            Image(systemName: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.orange)
                .accessibilityLabel("Дані можуть бути застарілими")
        }
    }

    private var footer: some View {
        HStack {
            if refreshFailed {
                Label("Не вдалося оновити", systemImage: "wifi.exclamationmark").foregroundStyle(.orange)
            } else if p.showsStaleWarning {
                StaleWarningLabel()
            }
            Spacer()
            if let updated = p.updatedText { Text(updated).foregroundStyle(.secondary) }
        }
        .font(.caption2)
        .labelStyle(.titleAndIcon)
    }
}

extension PlaceCardContent where Accessory == EmptyView {
    init(name: String, presentation: SubgroupPresentation, style: PlaceCardStyle = .app, refreshFailed: Bool = false) {
        self.init(name: name, presentation: presentation, style: style, refreshFailed: refreshFailed) { EmptyView() }
    }
}
