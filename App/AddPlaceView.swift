import SwiftUI

/// Форма «Додати місце»: назва → область → черга → підчерга.
struct AddPlaceView: View {
    let onSave: (Place) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft = PlaceDraft()
    @FocusState private var nameFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Наприклад, Дім або Робота", text: $draft.name)
                        .focused($nameFocused)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.done)
                } header: {
                    Text("Назва")
                } footer: {
                    if draft.trimmedName.count > PlaceDraft.maxNameLength {
                        Text("Назва задовга: до \(PlaceDraft.maxNameLength) символів.").foregroundStyle(.red)
                    }
                }

                Section {
                    Picker("Область", selection: $draft.region) {
                        ForEach(Region.selectable, id: \.self) { Text($0.title).tag($0) }
                    }
                } header: {
                    Text("Область")
                } footer: {
                    if draft.region.hasScheduleData {
                        Text("Поки що доступна лише Черкаська область. Інші області з’являться пізніше.")
                    } else {
                        Text("Для цієї області зараз немає графіків відключень, тому додати місце не можна.")
                    }
                }

                if draft.region.hasScheduleData {
                    Section("Черга та підчерга") {
                        Picker("Черга", selection: $draft.queue) {
                            ForEach(1...6, id: \.self) { Text("Черга \($0)").tag($0) }
                        }
                        Picker("Підчерга", selection: $draft.sub) {
                            ForEach(1...2, id: \.self) { Text("\(draft.queue).\($0)").tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            .navigationTitle("Додати місце")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Скасувати") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Зберегти") {
                        if let place = draft.makePlace() {
                            onSave(place)
                            dismiss()
                        }
                    }
                    .disabled(!draft.isValid)
                }
            }
            .onAppear { nameFocused = true }
        }
    }
}
