import XCTest

final class OutageDataTests: XCTestCase {
    /// Скорочений реальний формат OE_OUTAGE_DATA (12.11.2026): 1794434400 = 12.11.2026 00:00 за Києвом.
    static func json(_ hours11: [String: String], extraDay: String = "") -> String {
        let h = hours11.map { "\"\($0.key)\": \"\($0.value)\"" }.joined(separator: ",")
        return """
        {"regionId": "Chernihivoblenergo", "lastUpdated": "2026-11-11T22:04:38.037Z",
         "fact": {"data": {"1794434400": {"GPV1.1": {\(h)}, "GPV6.2": {"1": "no"}, "Other": {"1": "no"}}\(extraDay)},
                  "update": "12.11.2026 00:04", "today": 1794434400},
         "preset": {"time_type": {"yes": "Світло є"}}}
        """
    }

    private func allYes() -> [String: String] {
        Dictionary(uniqueKeysWithValues: (1...24).map { (String($0), "yes") })
    }

    private let url = OutageDataService.url(for: .chernihiv)

    func testParsesDayKeyAndSubgroups() throws {
        var hours = allYes(); hours["10"] = "no"
        let r = try OutageDataParser.parse(Data(Self.json(hours).utf8), sourceURL: url)
        XCTAssertEqual(r.regionID, "Chernihivoblenergo")
        XCTAssertEqual(Array(r.posts.keys), ["2026-11-12"])
        let post = try XCTUnwrap(r.posts["2026-11-12"])
        XCTAssertEqual(post.outages["1.1"], [MinuteRange(start: 540, end: 600)])
        XCTAssertNotNil(post.outages["6.2"])
        XCTAssertNil(post.outages["Other"])
    }

    func testHalfHourAndPossibleValues() {
        var hours = allYes()
        hours["1"] = "first"; hours["2"] = "second"; hours["3"] = "mfirst"; hours["4"] = "msecond"
        let r = OutageDataParser.parseHours(hours)
        XCTAssertEqual(r.outages, [MinuteRange(start: 0, end: 30), MinuteRange(start: 90, end: 150),
                                   MinuteRange(start: 210, end: 240)])
        XCTAssertTrue(r.unknown.isEmpty)
    }

    func testUnknownOrMissingValueIsUnknownForThatHourOnly() {
        var hours = allYes()
        hours["5"] = "maybe-later"
        hours.removeValue(forKey: "24")
        let r = OutageDataParser.parseHours(hours)
        XCTAssertTrue(r.outages.isEmpty)
        XCTAssertEqual(r.unknown, [MinuteRange(start: 240, end: 300), MinuteRange(start: 1380, end: 1440)])
    }

    func testUnknownHoursAreNeverShownAsAvailable() throws {
        var hours = allYes(); hours["5"] = "???"; hours["6"] = "no"
        let r = try OutageDataParser.parse(Data(Self.json(hours).utf8), sourceURL: url)
        let snapshot = ScheduleSnapshot(fetchedAt: Date(), posts: r.posts)
        let day = snapshot.schedule(for: Subgroup(queue: 1, sub: 1)!, dateKey: "2026-11-12")
        XCTAssertEqual(day.state(atMinute: 250), .unknown)
        XCTAssertEqual(day.state(atMinute: 330), .outage)
        XCTAssertEqual(day.state(atMinute: 100), .available)
        XCTAssertEqual(day.intervals.first?.start, 0)
        XCTAssertEqual(day.intervals.last?.end, 1440)
    }

    func testUTCMidnightTimestampMapsToSameKyivDate() throws {
        // Деякі файли дають північ UTC (напр. Закарпаття): 1792195200 = 2026-10-17T00:00Z → 17.10 за Києвом.
        let text = """
        {"regionId": "Uzhhorod", "fact": {"data": {"1792195200": {"GPV1.1": {"1": "no"}}}}}
        """
        let r = try OutageDataParser.parse(Data(text.utf8), sourceURL: url)
        XCTAssertEqual(Array(r.posts.keys), ["2026-10-17"])
    }

    func testBrokenFileIsAnError() {
        XCTAssertThrowsError(try OutageDataParser.parse(Data("<html>".utf8), sourceURL: url))
        XCTAssertThrowsError(try OutageDataParser.parse(Data("{\"regionId\": \"x\"}".utf8), sourceURL: url)) {
            XCTAssertEqual($0 as? ScheduleError, .structureChanged)
        }
    }

    func testServiceMergesWithHistoryAndUsesRegionFile() async throws {
        var hours = allYes(); hours["10"] = "no"
        let now = Fixtures.kyiv(2026, 11, 12, 9, 0)
        let fetcher = MockFetcher(results: [url: .success(Self.json(hours))])
        let previous = Fixtures.snapshot(posts: ["2026-11-05": ["1.1": [Fixtures.r(0, 60)]],
                                                 "2026-10-20": ["1.1": [Fixtures.r(0, 60)]]],
                                         fetchedAt: Fixtures.kyiv(2026, 11, 11, 9, 0))
        let service = OutageDataService(fetcher: fetcher, region: .chernihiv, now: { now })
        let snapshot = try await service.fetchLatest(previous: previous)
        XCTAssertEqual(snapshot.fetchedAt, now)
        XCTAssertNotNil(snapshot.posts["2026-11-12"])
        XCTAssertNotNil(snapshot.posts["2026-11-05"])
        XCTAssertNil(snapshot.posts["2026-10-20"])   // старше за 14 днів
        XCTAssertEqual(OutageDataService.url(for: .chernihiv).lastPathComponent, "Chernihivoblenergo.json")
    }

    func testSourceKeysPerPlace() {
        let home = Place(name: "Дім", subgroup: Subgroup(queue: 1, sub: 1)!)
        let parents = Place(name: "Батьки", region: .lviv, subgroup: Subgroup(queue: 2, sub: 1)!, source: .outageDataAPI)
        let work = Place(name: "Робота", subgroup: Subgroup(queue: 3, sub: 2)!)
        XCTAssertEqual(ScheduleSourceKey.active(for: [home, parents, work]),
                       [.cherkasySite, ScheduleSourceKey(source: .outageDataAPI, region: .lviv)])
        XCTAssertEqual(ScheduleSourceKey.active(for: []), [.cherkasySite])
        // Сайт є лише для Черкаської: місце іншої області завжди йде через API.
        let odd = Place(name: "x", region: .kharkiv, subgroup: Subgroup(queue: 1, sub: 1)!, source: .oblenergoSite)
        XCTAssertEqual(odd.sourceKey, ScheduleSourceKey(source: .outageDataAPI, region: .kharkiv))
    }

    func testOldCacheWithoutUnknownFieldStillDecodes() throws {
        let post = PublishedSchedulePost(dateKey: "2026-11-12", publishedAt: Date(timeIntervalSince1970: 0),
                                         sourceURL: url, title: "t", outages: ["1.1": []], spillover: [:])
        var json = String(decoding: try JSONEncoder().encode(post), as: UTF8.self)
        json = json.replacingOccurrences(of: ",\"unknown\":null", with: "")
        let decoded = try JSONDecoder().decode(PublishedSchedulePost.self, from: Data(json.utf8))
        XCTAssertNil(decoded.unknown)
    }
}
