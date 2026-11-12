import SwiftUI

struct WatchRootView: View {
    @Environment(WatchState.self) private var state

    var body: some View {
        NavigationStack {
            Group {
                if let place = state.place {
                    WatchPlaceView(place: place)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "iphone").font(.title2)
                        Text("Додайте місце в NoLight на iPhone").multilineTextAlignment(.center)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .toolbar {
                if state.places.count > 1 {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            WatchPlacePicker()
                        } label: {
                            Image(systemName: "list.bullet")
                        }
                        .accessibilityLabel("Вибрати місце")
                    }
                }
            }
        }
    }
}

/// Вибір місця «На годиннику».
struct WatchPlacePicker: View {
    @Environment(WatchState.self) private var state
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(state.places) { place in
            Button {
                state.choose(place)
                dismiss()
            } label: {
                HStack {
                    VStack(alignment: .leading) {
                        Text(place.name)
                        Text("\(place.region.title), \(place.subgroup.id)")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if place.id == state.placeID { Image(systemName: "checkmark") }
                }
            }
        }
        .navigationTitle("На годиннику")
    }
}

/// Картка місця: стан, відлік, шкала −2 год … +2 год.
struct WatchPlaceView: View {
    let place: Place
    @Environment(WatchState.self) private var state

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let snapshot = state.snapshot(for: place)
            let p = SubgroupPresentation(snapshot: snapshot, subgroup: place.subgroup, now: context.date)
            let window = TimelineWindow.make(snapshot: snapshot, subgroup: place.subgroup, now: context.date)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(place.name).font(.headline).lineLimit(1)
                        Spacer()
                        Text(place.subgroup.id).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    Text(p.status.state.watchHeadline)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(p.status.state.watchColor)
                    if let at = p.status.changeAt, at > context.date, let title = WatchCopy.countdownTitle(p.status) {
                        HStack {
                            Text(title).foregroundStyle(.secondary)
                            Spacer()
                            Text(timerInterval: context.date...at, countsDown: true, showsHours: true)
                                .monospacedDigit()
                        }
                        .font(.footnote)
                    } else if let detail = p.detail {
                        Text(detail).font(.footnote).foregroundStyle(.secondary)
                    }
                    WatchTimelineBar(window: window)
                    if p.showsExpiredWarning {
                        Label("Дані застаріли", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption2).foregroundStyle(.orange)
                    } else if p.showsStaleWarning {
                        Label("Застаріло", systemImage: "clock.badge.exclamationmark")
                            .font(.caption2).foregroundStyle(.orange)
                    }
                    if let updated = p.updatedText {
                        Text(updated).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .refreshable { await state.refresh() }
    }
}
