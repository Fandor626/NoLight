import Foundation

struct NewsListItem: Equatable, Sendable {
    let title: String
    let url: URL
    let publishedAt: Date?
}

/// Розбір офіційних дописів Черкасиобленерго. Чиста логіка без мережі й UI.
///
/// Формат допису (спостерігався у дописі "Оновлено графік погодинних відключень (ГПВ) на 10 листопада"):
///   Години відсутності електропостачання:
///   1.1 00:00 - 02:00, 04:00 - 08:00, ...
/// Перелічені інтервали — це ВІДКЛЮЧЕННЯ; усе інше в добі — світло є.
enum ScheduleParser {
    struct TitleInfo: Equatable {
        let day: Int
        let month: Int
        let isUpdate: Bool
    }

    struct ParsedPost: Equatable {
        var outages: [String: [MinuteRange]]
        var spillover: [String: [MinuteRange]]
    }

    static let months: [String: Int] = [
        "січня": 1, "лютого": 2, "березня": 3, "квітня": 4, "травня": 5, "червня": 6,
        "липня": 7, "серпня": 8, "вересня": 9, "жовтня": 10, "листопада": 11, "грудня": 12,
    ]

    /// Розпізнає лише "Графік погодинних відключень (ГПВ) на <день> <місяць>".
    /// ГОП (бізнес), прогнози та інші новини відсіюються.
    static func titleInfo(_ title: String) -> TitleInfo? {
        let normalized = title.replacingOccurrences(of: "\u{00A0}", with: " ")
        let pattern = #"графік(?:и)?\s+погодинних\s+відключень(?:\s*\(\s*ГПВ\s*\))?\s+на\s+(\d{1,2})\s+([а-яіїєґ]+)"#
        guard let m = normalized.regexMatches(pattern, options: [.caseInsensitive]).first,
              let day = normalized.substring(m.range(at: 1)).flatMap({ Int($0) }),
              let month = normalized.substring(m.range(at: 2)).flatMap({ months[$0.lowercased()] })
        else { return nil }
        return TitleInfo(day: day, month: month, isUpdate: normalized.lowercased().contains("оновлено"))
    }

    /// Шукає посилання /media/... із непорожнім текстом і найближчу після нього дату "dd.MM.yyyy HH:mm".
    /// Порожній результат = сигнал "структура сайту змінилась".
    static func parseNewsList(html: String, baseURL: URL) -> [NewsListItem] {
        let anchorPattern = #"<a\b[^>]*?\bhref\s*=\s*["']([^"']+)["'][^>]*>(.*?)</a>"#
        let matches = html.regexMatches(anchorPattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
        let datePattern = #"(\d{2})\.(\d{2})\.(\d{4})\s+(\d{1,2}):(\d{2})"#
        let total = html.utf16.count

        var items: [NewsListItem] = []
        var seen = Set<URL>()

        for (idx, m) in matches.enumerated() {
            guard let rawHref = html.substring(m.range(at: 1)),
                  let inner = html.substring(m.range(at: 2)) else { continue }
            let href = decodeEntities(rawHref)
            guard href.contains("/media/") else { continue }

            var title = collapseWhitespace(stripHTML(inner))
            guard !title.isEmpty,
                  let url = URL(string: href, relativeTo: baseURL)?.absoluteURL,
                  !seen.contains(url) else { continue }
            seen.insert(url)

            var publishedAt: Date?
            if let dm = title.regexMatches(datePattern).first {
                publishedAt = date(from: title, match: dm)
                title = collapseWhitespace(title.replacingRegex(datePattern, with: ""))
            } else {
                let tailStart = m.range.location + m.range.length
                var tailEnd = total
                for later in matches[(idx + 1)...] {
                    if let h = html.substring(later.range(at: 1)).map(decodeEntities),
                       h.contains("/media/"), h != href {
                        tailEnd = later.range.location
                        break
                    }
                }
                let length = min(max(tailEnd - tailStart, 0), 800)
                if length > 0,
                   let dm = html.regexMatches(datePattern, in: NSRange(location: tailStart, length: length)).first {
                    publishedAt = date(from: html, match: dm)
                }
            }
            items.append(NewsListItem(title: title, url: url, publishedAt: publishedAt))
        }
        return items
    }

    private static func date(from text: String, match m: NSTextCheckingResult) -> Date? {
        let nums = (1...5).compactMap { text.substring(m.range(at: $0)).flatMap { Int($0) } }
        guard nums.count == 5 else { return nil }
        return KyivTime.calendar.date(from: DateComponents(year: nums[2], month: nums[1], day: nums[0],
                                                           hour: nums[3], minute: nums[4]))
    }

    /// Витягує інтервали відключень по підчергах. Кидає помилку, якщо жодної підчерги не знайдено
    /// (інший формат допису) або час некоректний. Нічого не вгадує.
    static func parsePost(html: String) throws -> ParsedPost {
        let text = stripHTML(html)
        var outages: [String: [MinuteRange]] = [:]
        var spillover: [String: [MinuteRange]] = [:]
        let markerPattern = #"(?<![\d:.])([1-6])\.([12])(?![\d:.])"#

        for line in text.components(separatedBy: .newlines) {
            let markers = line.regexMatches(markerPattern)
            guard !markers.isEmpty else { continue }
            let ns = line as NSString
            for (i, m) in markers.enumerated() {
                guard let q = line.substring(m.range(at: 1)), let s = line.substring(m.range(at: 2)) else { continue }
                let id = "\(q).\(s)"
                let segStart = m.range.location + m.range.length
                let segEnd = i + 1 < markers.count ? markers[i + 1].range.location : ns.length
                guard segEnd > segStart else { continue }
                let segment = ns.substring(with: NSRange(location: segStart, length: segEnd - segStart))
                let parsed = try parseRanges(in: segment)
                guard !parsed.main.isEmpty else { continue }
                if outages[id] != nil { continue }   // перше входження виграє
                outages[id] = MinuteRange.normalized(parsed.main)
                if !parsed.spill.isEmpty { spillover[id] = MinuteRange.normalized(parsed.spill) }
            }
        }

        guard !outages.isEmpty else {
            throw ScheduleError.parsingFailed("У дописі не знайдено рядків виду «1.1 00:00 - 02:00».")
        }
        return ParsedPost(outages: outages, spillover: spillover)
    }

    /// "00:00 - 02:00, 04:00 – 08:00". Інтервал через північ ("22:00 - 02:00") ділиться на main та spill.
    static func parseRanges(in text: String) throws -> (main: [MinuteRange], spill: [MinuteRange]) {
        let pattern = #"(\d{1,2})\s*:\s*(\d{2})\s*[-–—−]\s*(\d{1,2})\s*:\s*(\d{2})"#
        var main: [MinuteRange] = []
        var spill: [MinuteRange] = []
        for m in text.regexMatches(pattern) {
            let nums = (1...4).compactMap { text.substring(m.range(at: $0)).flatMap { Int($0) } }
            guard nums.count == 4 else { continue }
            let (h1, m1, h2, m2) = (nums[0], nums[1], nums[2], nums[3])
            guard h1 <= 23, m1 <= 59, h2 <= 24, m2 <= 59, !(h2 == 24 && m2 != 0) else {
                throw ScheduleError.invalidData("Некоректний час: \(h1):\(m1) - \(h2):\(m2)")
            }
            let start = h1 * 60 + m1
            let end = h2 * 60 + m2
            if end > start {
                main.append(MinuteRange(start: start, end: end))
            } else if end < start {
                main.append(MinuteRange(start: start, end: 1440))
                if end > 0 { spill.append(MinuteRange(start: 0, end: end)) }
            } else {
                throw ScheduleError.invalidData("Порожній інтервал: \(h1):\(m1)")
            }
        }
        return (main, spill)
    }

    static func stripHTML(_ html: String) -> String {
        var s = html
        let removals = [#"<!--.*?-->"#, #"<script\b.*?</script>"#, #"<style\b.*?</style>"#,
                        #"<head\b.*?</head>"#, #"<noscript\b.*?</noscript>"#]
        for p in removals {
            s = s.replacingRegex(p, with: "", options: [.caseInsensitive, .dotMatchesLineSeparators])
        }
        s = s.replacingRegex(#"<br\s*/?>"#, with: "\n", options: [.caseInsensitive])
        s = s.replacingRegex(#"</(p|div|li|tr|h[1-6]|ul|ol|section|article|table)\s*>"#, with: "\n",
                             options: [.caseInsensitive])
        s = s.replacingRegex(#"<[^>]+>"#, with: "")
        return decodeEntities(s)
    }

    static func collapseWhitespace(_ s: String) -> String {
        s.replacingRegex(#"\s+"#, with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func decodeEntities(_ input: String) -> String {
        var r = input
        let ns = NSMutableString(string: r)
        if let re = try? NSRegularExpression(pattern: #"&#(x?[0-9a-fA-F]+);"#) {
            for m in re.matches(in: r, range: NSRange(location: 0, length: ns.length)).reversed() {
                let code = ns.substring(with: m.range(at: 1))
                let isHex = code.hasPrefix("x") || code.hasPrefix("X")
                let value: UInt32? = isHex ? UInt32(code.dropFirst(), radix: 16) : UInt32(code, radix: 10)
                if let v = value, let scalar = Unicode.Scalar(v) {
                    ns.replaceCharacters(in: m.range, with: String(Character(scalar)))
                }
            }
            r = ns as String
        }
        let named: [(String, String)] = [
            ("&nbsp;", " "), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&apos;", "'"),
            ("&ndash;", "–"), ("&mdash;", "—"), ("&laquo;", "«"), ("&raquo;", "»"), ("&amp;", "&"),
        ]
        for (k, v) in named { r = r.replacingOccurrences(of: k, with: v) }
        return r.replacingOccurrences(of: "\u{00A0}", with: " ")
    }
}

struct SelectedPost: Equatable, Sendable {
    let dateKey: String
    let item: NewsListItem
}

enum ScheduleSelector {
    /// Для кожної доби з вікна [сьогодні ... сьогодні+2] обирає НАЙНОВІШИЙ допис ГПВ.
    static func select(_ items: [NewsListItem], now: Date) -> [SelectedPost] {
        let today = KyivTime.dateKey(for: now)
        let last = KyivTime.addingDays(2, to: today)
        var best: [String: NewsListItem] = [:]

        for item in items {
            guard let info = ScheduleParser.titleInfo(item.title),
                  let key = KyivTime.dateKey(day: info.day, month: info.month, reference: item.publishedAt ?? now),
                  key >= today, key <= last else { continue }
            if let current = best[key] {
                if let a = item.publishedAt, a > (current.publishedAt ?? .distantPast) { best[key] = item }
            } else {
                best[key] = item
            }
        }
        return best.keys.sorted().compactMap { k in best[k].map { SelectedPost(dateKey: k, item: $0) } }
    }
}
