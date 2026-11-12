import ActivityKit
import SwiftUI
import WidgetKit

/// Live Activity місця (NOL-39): заблокований екран і Dynamic Island.
struct PlaceLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PlaceActivityAttributes.self) { context in
            PlaceActivityLockScreenView(attributes: context.attributes, content: context.state, isStale: context.isStale)
                .widgetURL(DeepLink.place(context.attributes.placeID))
                .activityBackgroundTint(Color(uiColor: .systemBackground).opacity(0.85))
        } dynamicIsland: { context in
            let c = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.placeName, systemImage: "bolt.fill")
                        .font(.caption).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.attributes.subgroupID).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    PlaceActivityCountdown(content: c, isStale: context.isStale, large: false)
                }
            } compactLeading: {
                Image(systemName: c.state == .outage ? "bolt.slash.fill" : "bolt.fill")
                    .foregroundStyle(c.state.textColor)
            } compactTrailing: {
                if let at = c.changeAt, !context.isStale, at > .now {
                    Text(timerInterval: Date.now...at, countsDown: true)
                        .monospacedDigit().frame(maxWidth: 52)
                } else {
                    Text("—")
                }
            } minimal: {
                Image(systemName: c.state == .outage ? "bolt.slash.fill" : "bolt.fill")
                    .foregroundStyle(c.state.textColor)
            }
            .widgetURL(DeepLink.place(context.attributes.placeID))
        }
    }
}

struct PlaceActivityLockScreenView: View {
    let attributes: PlaceActivityAttributes
    let content: PlaceActivityContent
    let isStale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(attributes.placeName).font(.subheadline.weight(.semibold)).lineLimit(1)
                SubgroupBadge(text: attributes.subgroupID, compact: true)
                Spacer()
                Image(systemName: "bolt.fill").foregroundStyle(.secondary).font(.caption)
            }
            PlaceActivityCountdown(content: content, isStale: isStale, large: true)
        }
        .padding(16)
    }
}

/// Стан + відлік до наступної зміни або пояснення, чому відліку немає.
struct PlaceActivityCountdown: View {
    let content: PlaceActivityContent
    let isStale: Bool
    let large: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(PlaceActivityPlanner.headline(content))
                .font(large ? .title2.weight(.bold) : .headline)
                .foregroundStyle(content.state.textColor)
            Spacer()
            if let at = content.changeAt, !isStale, at > .now, let title = PlaceActivityPlanner.countdownTitle(content) {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(title).font(.caption).foregroundStyle(.secondary)
                    Text(timerInterval: Date.now...at, countsDown: true, showsHours: true)
                        .font(large ? .title2.monospacedDigit().weight(.semibold) : .headline.monospacedDigit())
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        if content.changeAt == nil || isStale || (content.changeAt ?? .now) <= .now {
            Text(PlaceActivityPlanner.fallbackText(content, isStale: isStale, now: .now))
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
