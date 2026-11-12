import SwiftUI

/// Деталі місця: стан зараз, перемикач «Сьогодні / Завтра», шкала й інтервали.
struct PlaceDetailView: View {
    let placeID: UUID
    @Environment(AppState.self) private var state
    @State private var mode = DayMode.today
    /// Вибраний минулий день (dateKey); nil — учора.
    @State private var pastKey: String?
    @State private var showingSettings = false
    @State private var showingComparison = false

    enum DayMode: Hashable { case earlier, today, tomorrow }

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
        .toolbar {
            if place != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { showingSettings = true } label: { Label("Налаштування місця", systemImage: "slider.horizontal.3") }
                        if place?.region == .cherkasy {
                            Button { showingComparison = true } label: {
                                Label("Порівняння джерел", systemImage: "rectangle.split.2x1")
                            }
                        }
                    } label: { Image(systemName: "ellipsis.circle") }
                    .accessibilityLabel("Дії з місцем")
                }
            }
        }
        .sheet(isPresented: $showingSettings) { PlaceSettingsView(placeID: placeID) }
        .sheet(isPresented: $showingComparison) { SourceComparisonView(placeID: placeID) }
    }

    private func content(place: Place) -> some View {
        let subgroup = place.subgroup
        return TimelineView(.periodic(from: .now, by: 30)) { context in
            let p = SubgroupPresentation(snapshot: state.snapshot(for: place), subgroup: subgroup, now: context.date)
            let pastKeys = HistoryWindow.previousKeys(today: p.todayKey)
            let selectedPast = pastKey.flatMap { pastKeys.contains($0) ? $0 : nil } ?? pastKeys[0]
            let day: DaySchedule = {
                switch mode {
                case .today: return p.today
                case .tomorrow: return p.tomorrow
                case .earlier:
                    return HistoryWindow.pastSchedule(snapshot: state.snapshot(for: place), subgroup: subgroup, dateKey: selectedPast)
                }
            }()
            let dayDate = KyivTime.startOfDay(dateKey: day.dateKey) ?? context.date
            let isPast = mode == .earlier

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    DataStatusBanners(state: state, now: context.date)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            SubgroupBadge(text: subgroup.id)
                            Text("\(place.region.title) обл.").font(.subheadline).foregroundStyle(.secondary)
                            if place.sourceKey.source == .outageDataAPI { UnofficialSourceBadge() }
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

                    Picker("День", selection: $mode) {
                        Text("Раніше").tag(DayMode.earlier)
                        Text("Сьогодні").tag(DayMode.today)
                        Text("Завтра").tag(DayMode.tomorrow)
                    }
                    .pickerStyle(.segmented)

                    if isPast {
                        PastDayStrip(keys: pastKeys, selected: selectedPast) { pastKey = $0 }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text(dayTitle(mode: mode, date: dayDate)).font(.headline)
                        if isPast && day.kind != .published {
                            Label(HistoryWindow.unknownTitle, systemImage: "questionmark.circle")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                        } else if let title = day.kind.placeholderTitle {
                            // Замість порожньої сірої шкали — зрозуміле повідомлення.
                            Label(title, systemImage: "calendar.badge.clock")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                        } else {
                            TimelineBarView(intervals: day.intervals,
                                            nowMinute: mode == .today ? p.minuteNow : nil,
                                            barHeight: 22,
                                            hourLabels: [0, 3, 6, 9, 12, 15, 18, 21, 24])
                            Legend()
                        }
                    }
                    .card()

                    IntervalListView(day: day, messageOverride: isPast && day.kind != .published
                                     ? HistoryWindow.unknownMessage : nil).card()

                    let changes = ScheduleChangeHistory.entries(for: place.id, in: state.changeHistory)
                    if !changes.isEmpty {
                        ChangeHistoryView(changes: changes).card()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        if let updated = p.updatedText { Text(updated) }
                        if let published = day.publishedAt {
                            Text((place.sourceKey.source == .oblenergoSite ? "Допис на сайті: " : "Оновлено в API: ")
                                 + KyivTime.shortDateTimeString(published))
                        }
                        Text("Джерело: " + place.sourceKey.source.title)
                    }
                    .font(.footnote).foregroundStyle(.secondary)
                }
                .padding()
            }
            .refreshable { await state.refresh() }
        }
    }
}

extension PlaceDetailView {
    fileprivate func dayTitle(mode: DayMode, date: Date) -> String {
        switch mode {
        case .today: return "Графік на сьогодні"
        case .tomorrow: return "Завтра, " + KyivTime.longDateString(date)
        case .earlier: return KyivTime.longDateString(date).capitalized
        }
    }
}

/// Горизонтальний вибір одного з попередніх днів (новіші ліворуч).
private struct PastDayStrip: View {
    let keys: [String]
    let selected: String
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(keys, id: \.self) { key in
                    let isOn = key == selected
                    Button { onSelect(key) } label: {
                        Text(KyivTime.shortDayString(dateKey: key))
                            .font(.subheadline.weight(isOn ? .semibold : .regular))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(isOn ? Color.accentColor.opacity(0.18) : Color(uiColor: .secondarySystemGroupedBackground),
                                        in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
    }
}

/// «Зміни графіка» (NOL-24): коли змінився графік і як саме.
private struct ChangeHistoryView: View {
    let changes: [ScheduleChange]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Зміни графіка").font(.headline)
            ForEach(Array(changes.enumerated()), id: \.offset) { _, change in
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(KyivTime.shortDateTimeString(change.detectedAt)) · графік на \(dayTitle(change.dateKey))")
                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text("Було: " + ScheduleChangeDetector.describe(change.old))
                        .font(.subheadline).foregroundStyle(.secondary).strikethrough()
                    Text("Стало: " + ScheduleChangeDetector.describe(change.new))
                        .font(.subheadline)
                }
            }
        }
    }

    private func dayTitle(_ key: String) -> String {
        KyivTime.startOfDay(dateKey: key).map { KyivTime.longDateString($0) } ?? key
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
    /// Інший текст замість стандартного пояснення (напр., для минулого дня без даних).
    var messageOverride: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Інтервали").font(.headline)
            if let message = messageOverride ?? day.kind.placeholderMessage {
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
