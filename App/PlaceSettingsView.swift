import SwiftUI

/// Налаштування місця (NOL-17): джерело графіка. Вибір є лише для Черкаської області.
struct PlaceSettingsView: View {
    let placeID: UUID
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    private var place: Place? { state.places.first { $0.id == placeID } }

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
                    } header: {
                        Text("Попередження")
                    } footer: {
                        Text("Локальні сповіщення за графіком — щоб вчасно запустити або вимкнути генератор. Час налаштовується окремо. Плануються найближчі відключення; список оновлюється після кожного оновлення графіка.")
                    }
                } else {
                    ContentUnavailableView("Місце видалено", systemImage: "mappin.slash")
                }
            }
            .navigationTitle(place?.name ?? "Місце")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } } }
        }
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
