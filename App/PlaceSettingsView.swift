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
