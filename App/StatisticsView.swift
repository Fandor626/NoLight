import SwiftUI

/// «Статистика» (NOL-25): години зі світлом і без світла за сьогодні, завтра та попередні дні.
struct StatisticsView: View {
    let placeID: UUID
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var period = StatisticsPeriod.seven

    private var place: Place? { state.places.first { $0.id == placeID } }
    /// Межі ночі (NOL-26). Налаштування — NOL-27.
    private var night: NightBounds { .default }

    var body: some View {
        NavigationStack {
            Group {
                if let place {
                    list(place: place)
                } else {
                    ContentUnavailableView("Місце видалено", systemImage: "mappin.slash")
                }
            }
            .navigationTitle("Статистика")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } }
            }
        }
    }

    private func list(place: Place) -> some View {
        let stats = StatisticsCalculator.statistics(snapshot: state.snapshot(for: place), subgroup: place.subgroup,
                                                    now: .now, period: period, night: night)
        return List {
            Section {
                StatisticsDayRow(title: "Сьогодні", day: stats.today, showsSplit: true)
                if let tomorrow = stats.tomorrow {
                    StatisticsDayRow(title: "Завтра", day: tomorrow, showsSplit: true)
                }
            } header: {
                Text("За графіком")
            } footer: {
                if stats.tomorrow == nil { Text("Графік на завтра ще не опубліковано.") }
            }

            Section {
                Picker("Період", selection: $period) {
                    ForEach(StatisticsPeriod.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                StatisticsTotalsRow(total: stats.previousTotal, knownDays: stats.knownPreviousDays)
                if stats.knownPreviousDays > 0 {
                    StatisticsPartRow(title: "Ніч", subtitle: night.title, minutes: stats.previousNightTotal)
                    StatisticsPartRow(title: "День", subtitle: nil, minutes: stats.previousDayTotal)
                }
            } header: {
                Text("Разом за \(period.title)")
            } footer: {
                if stats.unknownPreviousDays > 0 {
                    Text("Днів без даних: \(stats.unknownPreviousDays). Вони позначені «Невідомо» і не враховані в підсумку.")
                }
            }

            Section("Попередні дні") {
                ForEach(stats.previous, id: \.dateKey) { day in
                    StatisticsDayRow(title: KyivTime.shortDayString(dateKey: day.dateKey), day: day)
                }
            }
        }
    }
}

/// Рядок однієї доби: «зі світлом / без світла» або «Невідомо».
struct StatisticsDayRow: View {
    let title: String
    let day: DayStatistics
    /// Показувати під рядком «Ніч / День» (NOL-26).
    var showsSplit = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
            Spacer()
            if let m = day.minutes {
                VStack(alignment: .trailing, spacing: 2) {
                    StatisticsValues(minutes: m)
                    if m.unknown > 0 {
                        Text("Невідомо: " + StatisticsFormat.duration(m.unknown))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if showsSplit, let n = day.night, let d = day.daytime {
                        Text("Ніч без світла " + StatisticsFormat.duration(n.outage)
                             + " · День без світла " + StatisticsFormat.duration(d.outage))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            } else {
                Label(HistoryWindow.unknownTitle, systemImage: "questionmark.circle")
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// «💡 18 год · ⛔ 6 год» кольорами станів.
struct StatisticsValues: View {
    let minutes: PowerMinutes

    var body: some View {
        HStack(spacing: 10) {
            Label(StatisticsFormat.duration(minutes.available), systemImage: "lightbulb.fill")
                .foregroundStyle(PowerState.available.textColor)
                .accessibilityLabel("Зі світлом " + StatisticsFormat.duration(minutes.available))
            Label(StatisticsFormat.duration(minutes.outage), systemImage: "lightbulb.slash")
                .foregroundStyle(PowerState.outage.textColor)
                .accessibilityLabel("Без світла " + StatisticsFormat.duration(minutes.outage))
        }
        .font(.subheadline.monospacedDigit())
        .labelStyle(.titleAndIcon)
    }
}

struct StatisticsTotalsRow: View {
    let total: PowerMinutes
    let knownDays: Int

    var body: some View {
        if knownDays == 0 {
            Label("Немає днів із даними", systemImage: "questionmark.circle").foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                StatisticsValues(minutes: total)
                if let share = StatisticsFormat.outageShare(total) {
                    Text("Без світла \(share)% часу · днів із даними: \(knownDays)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if total.unknown > 0 {
                    Text("Невідомо: " + StatisticsFormat.duration(total.unknown))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// «Ніч 00:00–06:00 · 💡 4 год · ⛔ 2 год» у підсумку за період (NOL-26).
struct StatisticsPartRow: View {
    let title: String
    let subtitle: String?
    let minutes: PowerMinutes

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary).monospacedDigit() }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                StatisticsValues(minutes: minutes)
                if minutes.unknown > 0 {
                    Text("Невідомо: " + StatisticsFormat.duration(minutes.unknown))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
