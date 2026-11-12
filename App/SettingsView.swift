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
    @State private var refreshMode = RefreshSettingsStore.shared.mode
    @State private var refreshInterval = RefreshSettingsStore.shared.interval
    @State private var nightStart = NightTime.date(minute: NightBoundsStore.shared.bounds.startMinute)
    @State private var nightEnd = NightTime.date(minute: NightBoundsStore.shared.bounds.endMinute)
    @State private var nightError: String?

    private var draftNight: NightBounds {
        NightBounds(startMinute: NightTime.minute(of: nightStart), endMinute: NightTime.minute(of: nightEnd))
    }

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

                Section {
                    Picker("Режим", selection: $refreshMode) {
                        ForEach(RefreshMode.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if refreshMode == .automatic {
                        Picker("Інтервал", selection: $refreshInterval) {
                            ForEach(RefreshInterval.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                        Label(RefreshCopy.intervalNote, systemImage: "info.circle")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Оновлення")
                } footer: {
                    Text(refreshMode == .automatic
                         ? "Графік оновлюється також при відкритті застосунку і самими віджетами. Якщо дані давно не оновлювались, застосунок і віджет попереджають про це."
                         : "Фонове оновлення вимкнено, віджети теж не оновлюються самі. Графік оновлюється при відкритті застосунку, кнопкою «Оновити» в застосунку або у віджеті.")
                }

                Section {
                    DatePicker("Початок ночі", selection: $nightStart, displayedComponents: .hourAndMinute)
                    DatePicker("Кінець ночі", selection: $nightEnd, displayedComponents: .hourAndMinute)
                    if let nightError {
                        Label(nightError, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                    }
                    if draftNight != .default {
                        Button("Скинути до 00:00–06:00") {
                            nightStart = NightTime.date(minute: NightBounds.default.startMinute)
                            nightEnd = NightTime.date(minute: NightBounds.default.endMinute)
                        }
                    }
                } header: {
                    Text("Статистика")
                } footer: {
                    Text("Ніч може переходити через північ, наприклад 22:00–06:00. Статистика перераховується одразу.")
                }
                .environment(\.timeZone, KyivTime.timeZone)

                Section("Джерело даних") {
                    Text("Графіки погодинних відключень (ГПВ), які АТ «Черкасиобленерго» публікує в новинах на офіційному сайті.")
                        .font(.footnote)
                    Link("Відкрити сайт Черкасиобленерго", destination: AppConfig.siteURL)
                }

                Section("Вигляд") {
                    NavigationLink {
                        ColorSettingsView()
                    } label: {
                        Label("Кольори", systemImage: "paintpalette")
                    }
                }

                Section("Про застосунок") {
                    LabeledContent("Версія", value: AppVersion.display)
                    Text("Неофіційний застосунок, не пов’язаний з АТ «Черкасиобленерго». Завжди звіряйтеся з офіційними повідомленнями.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Налаштування")
            .onChange(of: draftNight) { _, bounds in
                nightError = bounds.validationMessage
                NightBoundsStore.shared.save(bounds)
            }
            .onChange(of: refreshMode) { _, mode in
                RefreshSettingsStore.shared.mode = mode
                BackgroundRefresh.schedule()
            }
            .onChange(of: refreshInterval) { _, interval in
                RefreshSettingsStore.shared.interval = interval
                BackgroundRefresh.schedule()
            }
        }
    }
}
