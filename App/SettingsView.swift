import SwiftUI

/// Версія зі збірки: «1.0.14 (збірка 14)». Значення виставляє scripts/set-version.sh (кількість комітів у git).
enum AppVersion {
    static var display: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (збірка \(build))"
    }
}

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
                    LabeledContent("Версія", value: AppVersion.display)
                    Text("Неофіційний застосунок, не пов’язаний з АТ «Черкасиобленерго». Завжди звіряйтеся з офіційними повідомленнями.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Налаштування")
        }
    }
}
