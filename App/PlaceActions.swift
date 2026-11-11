import SwiftUI

/// Спільні діалоги для місця: перейменування (alert з полем) і видалення з підтвердженням.
struct PlaceActionsModifier: ViewModifier {
    @Environment(AppState.self) private var state
    @Binding var renaming: Place?
    @Binding var deleting: Place?
    @State private var newName = ""

    func body(content: Content) -> some View {
        content
            .alert("Перейменувати місце", isPresented: isRenaming, presenting: renaming) { place in
                TextField("Назва", text: $newName)
                Button("Скасувати", role: .cancel) {}
                Button("Зберегти") { state.renamePlace(place, to: newName) }
                    .disabled(Place.normalizedName(newName) == nil)
            } message: { _ in
                Text("До \(Place.maxNameLength) символів.")
            }
            .confirmationDialog(deleting.map { "Видалити «\($0.name)»?" } ?? "",
                                isPresented: isDeleting, titleVisibility: .visible, presenting: deleting) { place in
                Button("Видалити", role: .destructive) { state.removePlace(place) }
                Button("Скасувати", role: .cancel) {}
            } message: { _ in
                Text("Місце зникне зі списку разом з його налаштуваннями.")
            }
            .onChange(of: renaming) { _, place in newName = place?.name ?? "" }
    }

    private var isRenaming: Binding<Bool> {
        Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })
    }

    private var isDeleting: Binding<Bool> {
        Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
    }
}

extension View {
    func placeActions(renaming: Binding<Place?>, deleting: Binding<Place?>) -> some View {
        modifier(PlaceActionsModifier(renaming: renaming, deleting: deleting))
    }
}

/// «Керувати місцями»: перетягування для зміни порядку, свайп для перейменування й видалення.
struct ManagePlacesView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var renaming: Place?
    @State private var deleting: Place?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(state.places) { place in
                        HStack(spacing: 12) {
                            SubgroupBadge(text: place.subgroup.id, compact: true)
                            Text(place.name)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { renaming = place }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { deleting = place } label: {
                                Label("Видалити", systemImage: "trash")
                            }
                            Button { renaming = place } label: {
                                Label("Перейменувати", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                    .onMove { state.movePlaces(from: $0, to: $1) }
                } footer: {
                    Text("Натисніть «Змінити», щоб перетягнути місця. Свайп ліворуч — перейменувати або видалити.")
                }
            }
            .navigationTitle("Мої місця")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } }
            }
            .placeActions(renaming: $renaming, deleting: $deleting)
            .overlay {
                if state.places.isEmpty {
                    ContentUnavailableView("Немає місць", systemImage: "mappin.slash")
                }
            }
        }
    }
}
