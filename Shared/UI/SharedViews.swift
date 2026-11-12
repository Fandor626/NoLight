import SwiftUI
import UIKit

/// Приглушена палітра: менш агресивна за системні червоний/зелений, окремі відтінки для світлої й темної теми.
private extension UIColor {
    static func dynamic(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? dark : light }
    }

    static let softGreen = dynamic(light: UIColor(red: 0.30, green: 0.67, blue: 0.46, alpha: 1),
                                   dark: UIColor(red: 0.34, green: 0.66, blue: 0.48, alpha: 1))
    static let softRed = dynamic(light: UIColor(red: 0.83, green: 0.40, blue: 0.38, alpha: 1),
                                 dark: UIColor(red: 0.78, green: 0.42, blue: 0.40, alpha: 1))
}

extension PowerState {
    var color: Color {
        switch self {
        case .available: return Color(uiColor: .softGreen)
        case .outage: return Color(uiColor: .softRed)
        case .unknown: return Color(uiColor: .systemGray4)
        }
    }

    var textColor: Color {
        switch self {
        case .available: return Color(uiColor: .softGreen)
        case .outage: return Color(uiColor: .softRed)
        case .unknown: return .secondary
        }
    }

    var title: String {
        switch self {
        case .available: return "Світло є"
        case .outage: return "Відключення"
        case .unknown: return "Невідомо"
        }
    }
}

struct SubgroupBadge: View {
    let text: String
    var compact = false

    var body: some View {
        Text(text)
            .font(.system(size: compact ? 15 : 20, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, compact ? 7 : 10)
            .padding(.vertical, compact ? 3 : 5)
            .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: compact ? 8 : 10, style: .continuous))
            .accessibilityLabel("Підчерга \(text)")
    }
}

/// Горизонтальна 24-годинна смуга з маркером поточного часу.
struct TimelineBarView: View {
    let intervals: [ScheduleInterval]
    var nowMinute: Int? = nil
    var barHeight: CGFloat = 14
    var hourLabels: [Int] = [0, 6, 12, 18, 24]
    var showsMarkerLabel = true
    var labelFontSize: CGFloat = 9

    private var topInset: CGFloat { nowMinute == nil ? 0 : (showsMarkerLabel ? 22 : 8) }
    private var bottomInset: CGFloat { hourLabels.isEmpty ? 0 : 14 }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .topLeading) {
                bar(width: w).offset(y: topInset)
                ForEach(hourLabels, id: \.self) { h in
                    let x = TimelineGeometry.markerX(minute: h * 60, width: Double(w))
                    Text(String(format: "%02d", h))
                        .font(.system(size: labelFontSize, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .fixedSize()
                        .position(x: CGFloat(TimelineGeometry.clampedLabelCenter(x: x, labelWidth: 16, containerWidth: Double(w))),
                                  y: topInset + barHeight + 8)
                }
                if let nowMinute { marker(width: w, minute: nowMinute) }
            }
        }
        .frame(height: topInset + barHeight + bottomInset)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private func bar(width w: CGFloat) -> some View {
        let frames = TimelineGeometry.segmentFrames(intervals, width: Double(w))
        return ZStack(alignment: .topLeading) {
            ForEach(Array(frames.enumerated()), id: \.offset) { _, f in
                Rectangle()
                    .fill(f.state.color)
                    .frame(width: CGFloat(f.width), height: barHeight)
                    .offset(x: CGFloat(f.x))
            }
        }
        .frame(width: w, height: barHeight, alignment: .topLeading)
        .background(PowerState.unknown.color)
        .clipShape(RoundedRectangle(cornerRadius: barHeight * 0.4, style: .continuous))
    }

    @ViewBuilder
    private func marker(width w: CGFloat, minute: Int) -> some View {
        let x = CGFloat(TimelineGeometry.markerX(minute: minute, width: Double(w)))
        let labelCenter = CGFloat(TimelineGeometry.clampedLabelCenter(x: Double(x), labelWidth: 34, containerWidth: Double(w)))
        ZStack(alignment: .topLeading) {
            if showsMarkerLabel {
                Text(KyivTime.minuteString(minute))
                    .font(.system(size: 10, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .fixedSize()
                    .position(x: labelCenter, y: 6)
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(.primary)
                    .position(x: x, y: 16)
            }
            Rectangle()
                .fill(Color(uiColor: .systemBackground))
                .frame(width: 4, height: barHeight + 4)
                .position(x: x, y: topInset + barHeight / 2)
            Rectangle()
                .fill(Color.primary)
                .frame(width: 2, height: barHeight + 4)
                .position(x: x, y: topInset + barHeight / 2)
        }
    }

    private var accessibilitySummary: String {
        let outages = intervals.filter { $0.state == .outage }
            .map { "\(KyivTime.minuteString($0.start)) – \(KyivTime.minuteString($0.end))" }
        var text = outages.isEmpty ? "Графік доби." : "Відключення: " + outages.joined(separator: ", ") + "."
        if let nowMinute { text += " Зараз " + KyivTime.minuteString(nowMinute) + "." }
        return text
    }
}

/// Свіжість даних (NOL-16): «застаріло» після 1 год, «протерміновано» після 24 год.
enum FreshnessCopy {
    static let stale = "Застаріло"
    static let expired = "Протерміновано"
    static let unofficial = "Неофіційне джерело"
}

struct StaleWarningLabel: View {
    var body: some View {
        Label(FreshnessCopy.stale, systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(.orange)
            .accessibilityLabel("Дані застаріли: останнє оновлення понад годину тому")
    }
}

struct ExpiredWarningLabel: View {
    var body: some View {
        Label(FreshnessCopy.expired, systemImage: "clock.badge.exclamationmark.fill")
            .foregroundStyle(.red)
            .accessibilityLabel("Дані протерміновані: останнє оновлення понад добу тому")
    }
}

/// Позначка «неофіційне джерело» для графіків з API (NOL-16).
struct UnofficialSourceBadge: View {
    var compact = false
    var body: some View {
        Text(compact ? "неофіц." : FreshnessCopy.unofficial.lowercased())
            .font(.system(size: compact ? 9 : 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Color.secondary.opacity(0.15), in: Capsule())
            .accessibilityLabel(FreshnessCopy.unofficial)
    }
}
