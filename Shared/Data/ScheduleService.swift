import Foundation

/// Отримує й розбирає графіки з офіційного сайту. Не знає про кеш і UI.
struct ScheduleService: Sendable {
    let fetcher: HTMLFetching
    let newsListURL: URL
    let now: @Sendable () -> Date

    init(fetcher: HTMLFetching, newsListURL: URL, now: @escaping @Sendable () -> Date = { Date() }) {
        self.fetcher = fetcher
        self.newsListURL = newsListURL
        self.now = now
    }

    /// Повертає новий знімок, злитий із попереднім. Кидає помилку (кеш тоді не чіпається), якщо:
    /// сторінку не вдалося завантажити; у списку немає жодного допису (змінилась структура сайту);
    /// усі знайдені дописи ГПВ не вдалося розпізнати.
    func fetchLatest(previous: ScheduleSnapshot?) async throws -> ScheduleSnapshot {
        let currentDate = now()
        let listHTML = try await fetcher.fetch(newsListURL)
        let items = ScheduleParser.parseNewsList(html: listHTML, baseURL: newsListURL)
        guard !items.isEmpty else { throw ScheduleError.structureChanged }

        let selected = ScheduleSelector.select(items, now: currentDate)
        // Історія: зберігаємо дописи за останні `historyDays` днів, старіші видаляються (NOL-14).
        let cutoff = HistoryWindow.oldestKey(today: KyivTime.dateKey(for: currentDate))
        var posts = (previous?.posts ?? [:]).filter { $0.key >= cutoff }
        var problems = Set<String>()
        var firstError: ScheduleError?
        var understood = 0

        for sel in selected {
            if let old = posts[sel.dateKey], let published = sel.item.publishedAt, old.publishedAt >= published {
                understood += 1   // у кеші вже є цей або новіший допис
                continue
            }
            do {
                let html = try await fetcher.fetch(sel.item.url)
                let parsed = try ScheduleParser.parsePost(html: html)
                posts[sel.dateKey] = PublishedSchedulePost(
                    dateKey: sel.dateKey,
                    publishedAt: sel.item.publishedAt ?? currentDate,
                    sourceURL: sel.item.url,
                    title: sel.item.title,
                    outages: parsed.outages,
                    spillover: parsed.spillover)
                understood += 1
            } catch let error as ScheduleError {
                switch error {
                case .offline, .serverUnavailable:
                    throw error   // мережеві збої скасовують усе оновлення
                default:
                    firstError = firstError ?? error
                    problems.insert(sel.dateKey)
                }
            }
        }

        if !selected.isEmpty, understood == 0, let firstError { throw firstError }
        return ScheduleSnapshot(fetchedAt: currentDate, posts: posts, problemDates: problems.sorted())
    }
}
