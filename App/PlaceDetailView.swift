import SwiftUI

/// Деталі місця: стан зараз, перемикач «Сьогодні / Завтра», шкала й інтервали.
struct PlaceDetailView: View {
    let placeID: UUID
    @Environment(AppState.self) private var state
    @State private var showTomorrow = false

    /// Актуальна версія місця (назва могла змінитися); nil — якщо місце видалено.
    private var place: Place? { state.places.first { $0.id == placeID } }

    var body: some View {
        Group {
            if let place {
                content(place: place)
            } else {
                ContentUnavailableView("Місце видалено", systemImage: "mappin.slash")
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(place?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func content(place: Place) -> some View {
        let subgroup = place.subgroup
        return TimelineView(.periodic(from: .now, by: 30)) { context in
            let p = SubgroupPresentation(snapshot: state.snapshot, subgroup: subgroup, now: context.date)
            let day = showTomorrow ? p.tomorrow : p.today
            let dayDate = showTomorrow
                ? (KyivTime.startOfDay(dateKey: p.tomorrowKey) ?? context.date)
                : context.date

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    DataStatusBanners(state: state, now: context.date)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            SubgroupBadge(text: subgroup.id)
                            Text("\(place.region.title) обл.").font(.subheadline).foregroundStyle(.secondary)
                            Spacer()
                            Text(KyivTime.longDateString(context.date).capitalized)
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Text(p.headline)
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .foregroundStyle(p.status.state.textColor)
                        if let detail = p.detail { Text(detail).foregroundStyle(.secondary) }
                        if let at = p.status.changeAt, at > context.date {
                            HStack(spacing: 6) {
                                Text("До зміни:").foregroundStyle(.secondary)
                                Text(timerInterval: context.date...at, countsDown: true, showsHours: true)
                                    .monospacedDigit()
                                    .multilineTextAlignment(.leading)
                            }
                            .font(.subheadline)
                        }
                    }
                    .card()

                    Picker("День", selection: $showTomorrow) {
                        Text("Сьогодні").tag(false)
                        Text("Завтра").tag(true)
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 12) {
                        Text(showTomorrow ? "Завтра, " + KyivTime.longDateString(dayDate) : "Графік на сьогодні")
                            .font(.headline)
                        if let title = day.kind.placeholderTitle {
                            // Замість порожньої сірої шкали — зрозуміле повідомлення.
                            Label(title, systemImage: "calendar.badge.clock")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                        } else {
                            TimelineBarView(intervals: day.intervals,
                                            nowMinute: showTomorrow ? nil : p.minuteNow,
                                            barHeight: 22,
                                            hourLabels: [0, 3, 6, 9, 12, 15, 18, 21, 24])
                            Legend()
                        }
                    }
                    .card()

                    IntervalListView(day: day).card()

                    VStack(alignment: .leading, spacing: 4) {
                        if let updated = p.updatedText { Text(updated) }
                        if let published = day.publishedAt {
                            Text("Допис на сайті: " + KyivTime.shortDateTimeString(published))
                        }
                        Text("Джерело: АТ «Черкасиобленерго»")
                    }
                    .font(.footnote).foregroundStyle(.secondary)
                }
                .padding()
            }
            .refreshable { await state.refresh() }
        }
    }
}

struct Legend: View {
    var body: some View {
        HStack(spacing: 14) {
            ForEach([PowerState.available, .outage, .unknown], id: \.self) { s in
                HStack(spacing: 5) {
                    Circle().fill(s.color).frame(width: 9, height: 9)
                    Text(s.title).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct IntervalListView: View {
    let day: DaySchedule

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Інтервали").font(.headline)
            if let message = day.kind.placeholderMessage {
                Text(message).font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(Array(day.intervals.enumerated()), id: \.offset) { _, i in
                    HStack {
                        Circle().fill(i.state.color).frame(width: 10, height: 10)
                        Text("\(KyivTime.minuteString(i.start)) – \(KyivTime.minuteString(i.end))").monospacedDigit()
                        Text(i.state.title).foregroundStyle(.secondary)
                        Spacer()
                        Text(durationText(i.duration)).font(.footnote).foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    private func durationText(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if m == 0 { return "\(h) год" }
        if h == 0 { return "\(m) хв" }
        return "\(h) год \(m) хв"
    }
}

extension View {
    func card() -> some View {
        self.padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
