import SwiftUI

/// «Порівняння джерел» для черкаського місця: сайт обленерго й API поряд (NOL-18).
struct SourceComparisonView: View {
    let placeID: UUID
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var showTomorrow = false

    private var place: Place? { state.places.first { $0.id == placeID } }
    private let sources: [PlaceSource] = [.oblenergoSite, .outageDataAPI]

    var body: some View {
        NavigationStack {
            Group {
                if let place {
                    content(place: place)
                } else {
                    ContentUnavailableView("Місце видалено", systemImage: "mappin.slash")
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Порівняння джерел")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } } }
            .task { await state.loadComparison() }
        }
    }

    private func content(place: Place) -> some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let days = sources.map { day(for: $0, place: place, now: context.date) }
            let diff = SourceComparison.differences(days[0], days[1])
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Підчерга \(place.subgroup.id), Черкаська обл.").font(.subheadline).foregroundStyle(.secondary)
                    Picker("День", selection: $showTomorrow) {
                        Text("Сьогодні").tag(false)
                        Text("Завтра").tag(true)
                    }
                    .pickerStyle(.segmented)

                    ForEach(Array(sources.enumerated()), id: \.offset) { index, source in
                        sourceCard(source: source, day: days[index], place: place,
                                   nowMinute: showTomorrow ? nil : KyivTime.minutes(of: context.date))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Різниця").font(.headline)
                        if days.contains(where: { $0.kind != .published }) {
                            Text("Порівняння неможливе: одне з джерел не має графіка на цю добу.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        } else if diff.isEmpty {
                            Label("Джерела збігаються", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                        } else {
                            DiffBarView(ranges: diff)
                            Text("Розбіжність: \(SourceComparison.differingMinutes(diff)) хв")
                                .font(.subheadline.weight(.semibold))
                            ForEach(Array(diff.enumerated()), id: \.offset) { _, r in
                                Text("\(KyivTime.minuteString(r.start)) – \(KyivTime.minuteString(r.end))")
                                    .font(.subheadline).monospacedDigit()
                            }
                        }
                    }
                    .card()
                }
                .padding()
            }
            .refreshable { await state.loadComparison(forceRefresh: true) }
        }
    }

    private func day(for source: PlaceSource, place: Place, now: Date) -> DaySchedule {
        let key = ScheduleSourceKey(source: source, region: .cherkasy)
        let p = SubgroupPresentation(snapshot: state.snapshots[key], subgroup: place.subgroup, now: now)
        return showTomorrow ? p.tomorrow : p.today
    }

    @ViewBuilder
    private func sourceCard(source: PlaceSource, day: DaySchedule, place: Place, nowMinute: Int?) -> some View {
        let key = ScheduleSourceKey(source: source, region: .cherkasy)
        let isPrimary = place.sourceKey.source == source
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(source.shortTitle).font(.headline)
                if source == .outageDataAPI { UnofficialSourceBadge() }
                Spacer()
                if isPrimary {
                    Text("Основне").font(.caption.weight(.semibold)).foregroundStyle(Color.accentColor)
                } else {
                    Button("Зробити основним") { state.setSource(source, for: place) }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.bordered)
                }
            }
            if let snapshot = state.snapshots[key] {
                Text("Оновлено " + KyivTime.shortDateTimeString(snapshot.fetchedAt))
                    .font(.caption).foregroundStyle(.secondary)
            }
            if state.snapshots[key] == nil, let error = state.errors[key] {
                Label("Джерело недоступне: " + error.message, systemImage: "wifi.exclamationmark")
                    .font(.subheadline).foregroundStyle(.orange)
            } else if let title = day.kind.placeholderTitle {
                Text(title).font(.subheadline).foregroundStyle(.secondary)
            } else {
                TimelineBarView(intervals: day.intervals, nowMinute: nowMinute, barHeight: 18,
                                hourLabels: [0, 3, 6, 9, 12, 15, 18, 21, 24])
            }
        }
        .card()
    }
}

/// Смуга 0–24 год, де виділено хвилини з розбіжностями.
private struct DiffBarView: View {
    let ranges: [MinuteRange]

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.secondary.opacity(0.15))
                ForEach(Array(ranges.enumerated()), id: \.offset) { _, r in
                    Rectangle().fill(Color.yellow)
                        .frame(width: max(1, CGFloat(TimelineGeometry.fraction(minute: r.end - r.start)) * geo.size.width))
                        .offset(x: CGFloat(TimelineGeometry.fraction(minute: r.start)) * geo.size.width)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .frame(height: 12)
        .accessibilityLabel("Розбіжність між джерелами")
    }
}
