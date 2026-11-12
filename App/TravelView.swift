import SwiftUI

/// «Подорож» (NOL-28): графік будь-якої області й підчерги без створення місця.
struct TravelView: View {
    @Environment(AppState.self) private var state
    @State private var selection = TravelSelection()
    @State private var day = DayChoice.today
    @State private var saving = false
    @State private var newName = ""
    @State private var savedName: String?
    @State private var now = Date.now
    private let tick = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    // Приїзд (NOL-29)
    @State private var arrivalMode = ArrivalMode.duration
    @State private var arrivalTime = Date.now.addingTimeInterval(3600)
    @State private var durationMinutes = 60

    enum DayChoice: Hashable { case today, tomorrow }
    enum ArrivalMode: Hashable { case time, duration }

    private var arrivalInput: ArrivalInput {
        switch arrivalMode {
        case .time: return .time(minute: KyivTime.minutes(of: arrivalTime))
        case .duration: return .duration(minutes: durationMinutes)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Область", selection: $selection.region) {
                        ForEach(Region.selectable, id: \.self) { Text($0.title).tag($0) }
                    }
                    Picker("Черга", selection: $selection.queue) {
                        ForEach(1...6, id: \.self) { Text("Черга \($0)").tag($0) }
                    }
                    Picker("Підчерга", selection: $selection.sub) {
                        ForEach(1...2, id: \.self) { Text("\(selection.queue).\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Куди їдете")
                } footer: {
                    Text("Перегляд не створює місце. Щоб бачити цей графік на головному екрані й у віджетах, збережіть його як місце.")
                }

                if let place = selection.transientPlace {
                    preview(place: place)
                }
            }
            .navigationTitle("Подорож")
            .refreshable { await state.loadPreview(selection.sourceKey) }
            .task(id: selection.sourceKey) { await state.loadPreview(selection.sourceKey) }
            .onReceive(tick) { now = $0 }
            .onChange(of: selection) { _, _ in savedName = nil }
            .alert("Зберегти як місце", isPresented: $saving) {
                TextField("Назва", text: $newName)
                Button("Скасувати", role: .cancel) {}
                Button("Зберегти") {
                    if let place = selection.makePlace(name: newName) {
                        state.addPlace(place)
                        savedName = place.name
                    }
                }
                .disabled(Place.normalizedName(newName) == nil)
            } message: {
                Text("\(selection.region.title) обл., підчерга \(selection.subgroup?.id ?? "")")
            }
        }
    }

    @ViewBuilder
    private func preview(place: Place) -> some View {
        let key = selection.sourceKey
        let p = SubgroupPresentation(snapshot: state.snapshot(forKey: key), subgroup: place.subgroup, now: now)
        let shown = day == .today ? p.today : p.tomorrow

        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SubgroupBadge(text: place.subgroup.id)
                    if key.source == .outageDataAPI { UnofficialSourceBadge() }
                    Spacer()
                    if state.previewLoading.contains(key) { ProgressView() }
                }
                Text(p.headline)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(p.status.state.textColor)
                if let detail = p.detail { Text(detail).foregroundStyle(.secondary) }
                if p.showsExpiredWarning { ExpiredWarningLabel() } else if p.showsStaleWarning { StaleWarningLabel() }
                if let error = state.error(forKey: key) {
                    Label(error.message, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote).foregroundStyle(.orange)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Зараз")
        }

        let forecast = ArrivalCalculator.forecast(snapshot: state.snapshot(forKey: key), subgroup: place.subgroup,
                                                  now: now, input: arrivalInput)
        Section {
            Picker("Як задати", selection: $arrivalMode) {
                Text("Час приїзду").tag(ArrivalMode.time)
                Text("Тривалість поїздки").tag(ArrivalMode.duration)
            }
            .pickerStyle(.segmented)
            switch arrivalMode {
            case .time:
                DatePicker("Приїду о", selection: $arrivalTime, displayedComponents: .hourAndMinute)
                    .environment(\.timeZone, KyivTime.timeZone)
            case .duration:
                Stepper(value: $durationMinutes, in: 15...ArrivalCalculator.maxDurationMinutes, step: 15) {
                    LabeledContent("В дорозі", value: TravelFormat.duration(durationMinutes))
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(forecast.arrivalText(now: now)).font(.subheadline).foregroundStyle(.secondary)
                Text(forecast.headline)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(forecast.status.state.textColor)
                if let detail = forecast.detail(now: now) {
                    Text(detail).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
            .accessibilityElement(children: .combine)
        } header: {
            Text("Коли приїдете")
        }

        Section {
            Picker("День", selection: $day) {
                Text("Сьогодні").tag(DayChoice.today)
                Text("Завтра").tag(DayChoice.tomorrow)
            }
            .pickerStyle(.segmented)
            if let title = shown.kind.placeholderTitle {
                Label(title, systemImage: "calendar.badge.clock").foregroundStyle(.secondary)
                if let message = shown.kind.placeholderMessage {
                    Text(message).font(.footnote).foregroundStyle(.secondary)
                }
            } else {
                TimelineBarView(intervals: shown.intervals,
                                nowMinute: day == .today ? p.minuteNow : nil,
                                barHeight: 20, hourLabels: [0, 6, 12, 18, 24])
                    .padding(.vertical, 4)
                Legend()
                if shown.outageIntervals.isEmpty {
                    Text("Відключень не заплановано").font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(Array(shown.outageIntervals.enumerated()), id: \.offset) { _, i in
                    HStack {
                        Circle().fill(i.state.color).frame(width: 9, height: 9)
                        Text("\(KyivTime.minuteString(i.start)) – \(KyivTime.minuteString(i.end))").monospacedDigit()
                        Spacer()
                        Text(TravelFormat.duration(i.duration)).font(.footnote).foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }
            }
        } header: {
            Text("Графік")
        } footer: {
            VStack(alignment: .leading, spacing: 2) {
                if let updated = p.updatedText { Text(updated) }
                Text("Джерело: " + key.source.title)
            }
        }

        Section {
            Button {
                newName = selection.suggestedName
                saving = true
            } label: {
                Label("Зберегти як місце", systemImage: "plus.circle.fill")
            }
            if let savedName {
                Label("Місце «\(savedName)» додано на головний екран", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green).font(.footnote)
            }
        }
    }
}
