import SwiftUI

/// Налаштування місця (NOL-17): джерело графіка. Вибір є лише для Черкаської області.
struct PlaceSettingsView: View {
    let placeID: UUID
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    private var place: Place? { state.places.first { $0.id == placeID } }
    /// «Завжди на екрані» (NOL-43).
    @State private var keepsCountdown = false
    @State private var countdownError: String?
    /// Місце, яке показує Apple Watch (NOL-46).
    @State private var watchPlaceID = WatchPlaceStore.shared.placeID

    var body: some View {
        NavigationStack {
            Form {
                if let place {
                    Section {
                        LabeledContent("Область", value: place.region.title)
                        LabeledContent("Підчерга", value: place.subgroup.id)
                    }
                    Section {
                        if place.availableSources.count > 1 {
                            Picker("Джерело", selection: Binding(
                                get: { place.sourceKey.source },
                                set: { state.setSource($0, for: place) })) {
                                ForEach(place.availableSources, id: \.self) { Text($0.shortTitle).tag($0) }
                            }
                            .pickerStyle(.segmented)
                        } else {
                            LabeledContent("Джерело", value: place.sourceKey.source.shortTitle)
                        }
                    } header: {
                        Text("Джерело графіка")
                    } footer: {
                        Text(footer(for: place))
                    }
                    Section {
                        Toggle("Перед відключенням", isOn: Binding(
                            get: { place.warnBeforeOutageMinutes != nil },
                            set: { state.setWarningBeforeOutage($0 ? Place.defaultWarningLead : nil, for: place) }))
                        if let lead = place.warnBeforeOutageMinutes {
                            Picker("За скільки", selection: Binding(
                                get: { lead },
                                set: { state.setWarningBeforeOutage($0, for: place) })) {
                                ForEach(Place.warningLeadOptions, id: \.self) { Text("\($0) хв").tag($0) }
                            }
                        }
                        Toggle("Перед поверненням світла", isOn: Binding(
                            get: { place.warnBeforeReturnMinutes != nil },
                            set: { state.setWarningBeforeReturn($0 ? Place.defaultWarningLead : nil, for: place) }))
                        if let lead = place.warnBeforeReturnMinutes {
                            Picker("За скільки", selection: Binding(
                                get: { lead },
                                set: { state.setWarningBeforeReturn($0, for: place) })) {
                                ForEach(Place.warningLeadOptions, id: \.self) { Text("\($0) хв").tag($0) }
                            }
                        }
                        Toggle("Про зміну графіка", isOn: Binding(
                            get: { place.notifiesScheduleChanges },
                            set: { state.setNotifyScheduleChanges($0, for: place) }))
                    } header: {
                        Text("Попередження")
                    } footer: {
                        Text("Локальні сповіщення за графіком — щоб вчасно запустити або вимкнути генератор. Час налаштовується окремо. Сповіщення про зміну графіка залежить від фонового оновлення iOS, тому може прийти із запізненням або лише після відкриття застосунку. Плануються найближчі відключення; список оновлюється після кожного оновлення графіка.")
                    }
                    Section {
                        Toggle("Відлік завжди на екрані", isOn: Binding(
                            get: { keepsCountdown },
                            set: { on in Task { await setCountdown(on, place: place) } }))
                        if let countdownError {
                            Label(countdownError, systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote).foregroundStyle(.red)
                        }
                    } header: {
                        Text("Заблокований екран")
                    } footer: {
                        Text("Відлік до наступної зміни прибирається лише тут або в меню «…». Якщо його випадково змахнути або iOS завершить його через 8 год, NoLight поверне його, щойно ви відкриєте застосунок.")
                    }
                    Section {
                        Toggle("Показувати на годиннику", isOn: Binding(
                            get: { watchPlaceID == place.id },
                            set: { on in
                                let id: UUID? = on ? place.id : nil
                                WatchPlaceStore.shared.placeID = id
                                watchPlaceID = id
                                WatchSync.shared.send()
                            }))
                    } header: {
                        Text("Apple Watch")
                    } footer: {
                        Text("Застосунок NoLight на годиннику й віджет показують одне місце. Вибрати його можна тут або на самому годиннику.")
                    }
                } else {
                    ContentUnavailableView("Місце видалено", systemImage: "mappin.slash")
                }
            }
            .navigationTitle(place?.name ?? "Місце")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } } }
            .task { keepsCountdown = LiveActivityManager.isKept(placeID) }
        }
    }

    private func setCountdown(_ on: Bool, place: Place) async {
        countdownError = nil
        guard on else {
            await LiveActivityManager.stop(placeID: place.id)
            keepsCountdown = false
            return
        }
        guard LiveActivityManager.isAvailable else {
            countdownError = "Live Activities вимкнено: Параметри → NoLight → Live Activities."
            keepsCountdown = false
            return
        }
        keepsCountdown = await LiveActivityManager.start(place: place, snapshot: state.snapshot(for: place))
        if !keepsCountdown { countdownError = "iOS не дозволила запустити відлік. Спробуйте ще раз пізніше." }
    }

    private func footer(for place: Place) -> String {
        if place.availableSources.count == 1 {
            return "Для цієї області графіки є лише в неофіційному джерелі OE_OUTAGE_DATA."
        }
        return place.sourceKey.source == .oblenergoSite
            ? "Офіційні дописи АТ «Черкасиобленерго». Рекомендовано за замовчуванням."
            : "Неофіційне джерело OE_OUTAGE_DATA. Може відрізнятися від офіційних дописів — порівняйте в «Порівняння джерел»."
    }
}
