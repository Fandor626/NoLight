import SwiftUI

struct SubgroupPickerView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(1...6, id: \.self) { queue in
                    Section("Черга \(queue)") {
                        ForEach(Subgroup.all.filter { $0.queue == queue }) { subgroup in
                            Button { state.toggle(subgroup) } label: {
                                HStack(spacing: 12) {
                                    SubgroupBadge(text: subgroup.id, compact: true)
                                    Text("Підчерга \(subgroup.id)")
                                    Spacer()
                                    if state.isSelected(subgroup) {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
                                    } else {
                                        Image(systemName: "circle").foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            .foregroundStyle(.primary)
                            .accessibilityAddTraits(state.isSelected(subgroup) ? .isSelected : [])
                        }
                    }
                }
            }
            .navigationTitle("Підчерги")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Готово") { dismiss() } } }
        }
    }
}
