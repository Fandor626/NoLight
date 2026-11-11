import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        NavigationStack {
            Form {
                Section("Дані") {
                    Button {
                        Task { await state.refresh() }
                    } label: {
                        HStack {
                            Text("Оновити зараз")
                            Spacer()
                            if state.isRefreshing { ProgressView() }
                        }
                    }
                    .disabled(state.isRefreshing)

                    LabeledContent("Останнє успішне оновлення") {
                        if let d = state.snapshot?.fetchedAt { Text(KyivTime.shortDateTimeString(d)) } else { Text("—") }
                    }
                    if let error = state.lastError {
                        Label(error.message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                    if !AppConfig.isAppGroupAvailable {
                        Label("App Group не налаштовано: віджети не бачитимуть збережені дані.",
                              systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                    }
                }

                Section("Автоматичне оновлення") {
                    Text("Графік оновлюється при відкритті застосунку, у фоні (коли це дозволяє iOS) і самими віджетами. Точний час фонового оновлення система не гарантує, тому віджет може відставати. Якщо дані давно не оновлювались, застосунок і віджет попереджають про це.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section("Джерело даних") {
                    Text("Графіки погодинних відключень (ГПВ), які АТ «Черкасиобленерго» публікує в новинах на офіційному сайті.")
                        .font(.footnote)
                    Link("Відкрити сайт Черкасиобленерго", destination: AppConfig.siteURL)
                }

                Section("Про застосунок") {
                    LabeledContent("Версія", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                    Text("Неофіційний застосунок, не пов’язаний з АТ «Черкасиобленерго». Завжди звіряйтеся з офіційними повідомленнями.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Налаштування")
        }
    }
}
