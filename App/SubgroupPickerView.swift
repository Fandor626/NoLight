import SwiftUI

/// Тимчасовий спосіб додати місце: вибір підчерги створює місце «Підчерга X.Y».
/// Замінюється формою «Додати місце» в NOL-11.
struct SubgroupPickerView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(1...6, id: \.self) { queue in
                    Section("Черга \(queue)") {
                        ForEach(Subgroup.all.filter { $0.queue == queue }) { subgroup in
                            Button { state.togglePlace(for: subgroup) } label: {
                                HStack(spacing: 12) {
                                    SubgroupBadge(text: subgroup.id, compact: true)
                                    Text("Підчерга \(subgroup.id)")
                                    Spacer()
                                    if state.hasPlace(with: subgroup) {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
                                    } else {
                                        Image(systemName: "circle").foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            .foregroundStyle(.primary)
                            .accessibilityAddTraits(state.hasPlace(with: subgroup) ? .isSelected : [])
                        }
                    }
                }
            }
            .navigationTitle("Додати місце")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Готово") { dismiss() } } }
        }
    }
}
