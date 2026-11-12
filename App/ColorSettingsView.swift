import SwiftUI
import UIKit
import WidgetKit

/// «Кольори» (NOL-32): вибір кольору «Світло є» і «Відключення» для світлої й темної теми.
struct ColorSettingsView: View {
    @State private var colors = ColorSettings.shared

    var body: some View {
        Form {
            Section {
                ColorThemePreview()
            } header: {
                Text("Як виглядає")
            } footer: {
                Text("Зміни одразу видно в застосунку й у віджетах.")
            }

            Section {
                ForEach(ColorPreset.all) { preset in
                    Button { apply(preset.theme) } label: {
                        HStack(spacing: 12) {
                            PresetSwatch(theme: preset.theme)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.title).foregroundStyle(.primary)
                                if let note = preset.note {
                                    Text(note).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if ColorPreset.matching(colors.theme) == preset {
                                Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .accessibilityAddTraits(ColorPreset.matching(colors.theme) == preset ? .isSelected : [])
                }
            } header: {
                Text("Готові набори")
            } footer: {
                if ColorPreset.matching(colors.theme) == nil { Text("Зараз вибрано власні кольори.") }
            }

            Section("Світла тема") {
                picker("Світло є", \.available.light)
                picker("Відключення", \.outage.light)
            }

            Section("Темна тема") {
                picker("Світло є", \.available.dark)
                picker("Відключення", \.outage.dark)
            }
        }
        .navigationTitle("Кольори")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func picker(_ title: String, _ path: WritableKeyPath<ColorTheme, RGBAColor>) -> some View {
        ColorPicker(title, selection: Binding(
            get: { Color(rgba: colors.theme[keyPath: path]) },
            set: { newValue in
                guard let rgba = RGBAColor(newValue) else { return }
                var theme = colors.theme
                theme[keyPath: path] = rgba
                apply(theme)
            }), supportsOpacity: false)
    }

    private func apply(_ theme: ColorTheme) {
        colors.theme = theme
        WidgetCenter.shared.reloadAllTimelines()
    }
}

/// Два кружечки кольорів пресету в поточній темі.
private struct PresetSwatch: View {
    let theme: ColorTheme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: -4) {
            Circle().fill(Color(rgba: theme.available.color(isDark: scheme == .dark)))
            Circle().fill(Color(rgba: theme.outage.color(isDark: scheme == .dark)))
        }
        .frame(width: 40, height: 22)
        .accessibilityHidden(true)
    }
}

/// Шкала-зразок у поточній темі: світло, відключення, невідомо.
struct ColorThemePreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TimelineBarView(intervals: [
                ScheduleInterval(start: 0, end: 360, state: .available),
                ScheduleInterval(start: 360, end: 600, state: .outage),
                ScheduleInterval(start: 600, end: 1080, state: .available),
                ScheduleInterval(start: 1080, end: 1260, state: .outage),
                ScheduleInterval(start: 1260, end: 1440, state: .unknown),
            ], barHeight: 18)
            HStack(spacing: 16) {
                Text("Світло є").foregroundStyle(PowerState.available.textColor)
                Text("Світла немає").foregroundStyle(PowerState.outage.textColor)
            }
            .font(.headline)
            Legend()
        }
        .padding(.vertical, 4)
        .accessibilityHidden(true)
    }
}

extension Color {
    init(rgba c: RGBAColor) {
        self.init(.sRGB, red: c.red, green: c.green, blue: c.blue, opacity: c.alpha)
    }
}

extension RGBAColor {
    /// Колір із ColorPicker у sRGB.
    init?(_ color: Color) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        self.init(red: Double(r), green: Double(g), blue: Double(b), alpha: 1)
    }
}
