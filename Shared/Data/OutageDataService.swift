import Foundation

/// Будь-яке джерело графіків: сайт обленерго (`ScheduleService`) або API (`OutageDataService`).
protocol ScheduleSourcing: Sendable {
    func fetchLatest(previous: ScheduleSnapshot?) async throws -> ScheduleSnapshot
}

extension ScheduleService: ScheduleSourcing {}

/// Графіки області з неофіційного API OE_OUTAGE_DATA (NOL-15).
struct OutageDataService: ScheduleSourcing {
    static let baseURL = URL(string: "https://raw.githubusercontent.com/yaroslav2901/OE_OUTAGE_DATA/main/data/")!

    let fetcher: HTMLFetching
    let region: Region
    let now: @Sendable () -> Date

    init(fetcher: HTMLFetching, region: Region, now: @escaping @Sendable () -> Date = { Date() }) {
        self.fetcher = fetcher
        self.region = region
        self.now = now
    }

    static func url(for region: Region) -> URL {
        baseURL.appendingPathComponent(region.apiFileName + ".json")
    }

    /// Нові дні з API зливаються з кешем; історія зберігається `AppConfig.historyDays` днів, як і для сайту.
    func fetchLatest(previous: ScheduleSnapshot?) async throws -> ScheduleSnapshot {
        let currentDate = now()
        let url = Self.url(for: region)
        let text = try await fetcher.fetch(url)
        let parsed = try OutageDataParser.parse(Data(text.utf8), sourceURL: url)
        let cutoff = HistoryWindow.oldestKey(today: KyivTime.dateKey(for: currentDate))
        var posts = (previous?.posts ?? [:]).filter { $0.key >= cutoff }
        for (key, post) in parsed.posts where key >= cutoff { posts[key] = post }
        return ScheduleSnapshot(fetchedAt: currentDate, posts: posts)
    }
}
