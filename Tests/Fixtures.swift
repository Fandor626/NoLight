import XCTest

enum Fixtures {
    static func kyiv(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date {
        KyivTime.calendar.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    /// Рядки з графіком взято з реального допису «Оновлено графік погодинних відключень (ГПВ) на 10 листопада».
    /// HTML-обгортка — реконструкція (сирий HTML сайту не спостерігався); парсер лише знімає теги.
    static let post10Nov = """
    <html><head><title>Оновлено графік</title>
    <meta name="description" content="1.1 05:00 - 06:00 (це НЕ має потрапити в результат)"></head>
    <body><nav><a href="/news">Новини</a></nav>
    <h1>Оновлено графік погодинних відключень (ГПВ) на 10 листопада</h1>
    <p>09.11.2026 23:06</p>
    <p>Оновлення графіка погодинних відключень (ГПВ) на 10 листопада</p>
    <p>Години відсутності електропостачання:</p>
    <p>1.1 00:00 - 02:00, 04:00 - 08:00, 10:00 - 14:00, 16:00 - 20:00, 22:00 - 24:00</p>
    <p>1.2 00:00 - 03:00, 05:00 - 09:00, 11:00 - 15:00, 17:00 - 21:00, 23:00 - 24:00</p>
    <p>2.1 00:00 - 02:00, 04:00 - 08:00, 10:00 - 14:00, 16:00 - 20:00, 22:00 - 24:00</p>
    <p>2.2 00:00 - 03:00, 05:00 - 09:00, 11:00 - 15:00, 17:00 - 21:00, 23:00 - 24:00</p>
    <p>3.1 00:00 - 04:00, 06:00 - 10:00, 12:00 - 16:00, 18:00 - 22:00</p>
    <p>3.2 01:00 - 05:00, 07:00 - 11:00, 13:00 - 17:00, 19:00 - 23:00</p>
    <p>4.1 00:00 - 04:00, 06:00 - 10:00, 12:00 - 16:00, 18:00 - 22:00</p>
    <p>4.2 01:00 - 05:00, 07:00 - 11:00, 13:00 - 17:00, 19:00 - 23:00</p>
    <p>5.1 02:00 - 06:00, 08:00 - 12:00, 14:00 - 18:00, 20:00 - 24:00</p>
    <p>5.2 00:00 - 01:00, 03:00 - 07:00, 09:00 - 13:00, 15:00 - 19:00, 21:00 - 24:00</p>
    <p>6.1 02:00 - 06:00, 08:00 - 12:00, 14:00 - 18:00, 20:00 - 24:00</p>
    <p>6.2 00:00 - 01:00, 03:00 - 07:00, 09:00 - 13:00, 15:00 - 19:00, 21:00 - 24:00</p>
    <p>Telegram - <a href="https://t.me/Cherkasyoblenergo_bot">https://t.me/Cherkasyoblenergo_bot</a></p>
    </body></html>
    """

    static func listItem(slug: String, title: String, date: String) -> String {
        """
        <div class="news-item"><a href="/media/\(slug)?lang=uk"><img src="/uploads/x.jpg" alt=""></a>
        <a href="/media/\(slug)?lang=uk">\(title)</a><span class="date">\(date)</span></div>
        """
    }

    static let slug10Update = "onovleno-hrafik-pohodynnykh-vidklyuchen-hpv-na-10-lystopada"
    static let slug10First = "hrafik-pohodynnykh-vidklyuchen-hpv-na-10-lystopada"
    static let slug9 = "hrafik-pohodynnykh-vidklyuchen-hpv-na-9-lystopada"

    static var listHTML: String {
        "<html><body><h1>Новини</h1>"
        + listItem(slug: slug10Update, title: "Оновлено графік погодинних відключень (ГПВ) на 10 листопада", date: "09.11.2026 23:06")
        + listItem(slug: slug10First, title: "Графік погодинних відключень (ГПВ) на 10 листопада", date: "09.11.2026 20:58")
        + listItem(slug: "gop-10", title: "Для промисловості та бізнесу Черкаської області 10 листопада діятимуть графіки обмеження потужності (ГОП)", date: "09.11.2026 20:45")
        + listItem(slug: slug9, title: "Графік погодинних відключень (ГПВ) на 9 листопада", date: "08.11.2026 23:03")
        + "<a href=\"/contacts?lang=uk\">Зворотний зв'язок</a></body></html>"
    }

    static func url(_ slug: String) -> URL {
        URL(string: "https://www.cherkasyoblenergo.com/media/\(slug)?lang=uk")!
    }

    static func snapshot(posts: [String: [String: [MinuteRange]]],
                         spillover: [String: [String: [MinuteRange]]] = [:],
                         fetchedAt: Date) -> ScheduleSnapshot {
        var out: [String: PublishedSchedulePost] = [:]
        for (key, outages) in posts {
            out[key] = PublishedSchedulePost(dateKey: key, publishedAt: fetchedAt,
                                             sourceURL: url("test-\(key)"), title: "test",
                                             outages: outages, spillover: spillover[key] ?? [:])
        }
        return ScheduleSnapshot(fetchedAt: fetchedAt, posts: out)
    }

    static func r(_ s: Int, _ e: Int) -> MinuteRange { MinuteRange(start: s, end: e) }
    static let sg11 = Subgroup(queue: 1, sub: 1)!
    static let sg21 = Subgroup(queue: 2, sub: 1)!
    static let sg22 = Subgroup(queue: 2, sub: 2)!

    static let outages11: [MinuteRange] = [r(0, 120), r(240, 480), r(600, 840), r(960, 1200), r(1320, 1440)]
}

struct MockFetcher: HTMLFetching {
    var results: [URL: Result<String, ScheduleError>]
    func fetch(_ url: URL) async throws -> String {
        guard let result = results[url] else { throw ScheduleError.serverUnavailable(status: 404) }
        return try result.get()
    }
}

func makeTempCacheURL() -> URL {
    URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("cl-test-\(UUID().uuidString)/cache.json")
}
