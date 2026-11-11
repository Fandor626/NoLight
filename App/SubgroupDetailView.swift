import SwiftUI

struct SubgroupDetailView: View {
    let subgroup: Subgroup
    @Environment(AppState.self) private var state
    @State private var showTomorrow = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
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
                        TimelineBarView(intervals: day.intervals,
                                        nowMinute: showTomorrow ? nil : p.minuteNow,
                                        barHeight: 22,
                                        hourLabels: [0, 3, 6, 9, 12, 15, 18, 21, 24])
                        Legend()
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
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Підчерга \(subgroup.id)")
        .navigationBarTitleDisplayMode(.inline)
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
            if day.kind != .published {
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

    private var message: String {
        switch day.kind {
        case .notPublished: return "Графік на цю добу ще не опубліковано. Це не означає, що відключень не буде."
        case .subgroupNotListed: return "У опублікованому графіку немає цієї підчерги."
        case .parseFailed: return "Графік опубліковано, але програма не змогла його розпізнати."
        case .noData: return "Немає актуальних даних. Оновіть графік, коли з’явиться інтернет."
        case .published: return ""
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
