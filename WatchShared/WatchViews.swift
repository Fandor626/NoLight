import SwiftUI

/// Кольори станів на годиннику (NOL-46): з налаштувань iPhone, темний варіант (годинник завжди темний).
extension PowerState {
    var watchColor: Color {
        let theme = ColorThemeStore.shared.theme
        switch self {
        case .available: return Color(rgba: theme.available.dark)
        case .outage: return Color(rgba: theme.outage.dark)
        case .unknown: return Color.gray.opacity(0.45)
        }
    }

    var watchHeadline: String {
        switch self {
        case .available: return "Світло є"
        case .outage: return "Світла немає"
        case .unknown: return "Невідомо"
        }
    }
}

extension Color {
    init(rgba c: RGBAColor) {
        self.init(.sRGB, red: c.red, green: c.green, blue: c.blue, opacity: c.alpha)
    }
}

/// Шкала −2 год … зараз … +2 год.
struct WatchTimelineBar: View {
    let window: TimelineWindowData
    var height: CGFloat = 10
    var showsLabels = true

    var body: some View {
        VStack(spacing: 2) {
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    ForEach(Array(window.segments.enumerated()), id: \.offset) { _, s in
                        Rectangle()
                            .fill(s.state.watchColor)
                            .frame(width: max(1, CGFloat(s.end - s.start) * w), height: height)
                            .offset(x: CGFloat(s.start) * w)
                    }
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 2, height: height + 6)
                        .offset(x: CGFloat(window.nowFraction) * w - 1, y: 0)
                }
                .frame(height: height + 6)
                .clipShape(RoundedRectangle(cornerRadius: height / 2))
            }
            .frame(height: height + 6)
            if showsLabels {
                HStack {
                    Text(KyivTime.timeString(window.from))
                    Spacer()
                    Text("зараз")
                    Spacer()
                    Text(KyivTime.timeString(window.to))
                }
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        let parts = window.segments.map { s -> String in
            let start = window.from.addingTimeInterval(s.start * window.to.timeIntervalSince(window.from))
            return "з \(KyivTime.timeString(start)) \(s.state.watchHeadline.lowercased())"
        }
        return "Графік на 4 години: " + parts.joined(separator: ", ")
    }
}

/// Текст «Відключення о 18:00» / «Світло з’явиться о 20:30» для годинника.
enum WatchCopy {
    static func detail(_ p: SubgroupPresentation) -> String? { p.detail }

    static func countdownTitle(_ status: PowerStatus) -> String? {
        guard status.changeAt != nil else { return nil }
        switch (status.state, status.nextState) {
        case (.available, .some(.outage)): return "До відключення"
        case (.outage, .some(.available)): return "До світла"
        default: return "До кінця графіка"
        }
    }
}
