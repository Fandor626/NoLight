import XCTest

final class SourceComparisonTests: XCTestCase {
    private let sg = Subgroup(queue: 1, sub: 1)!

    private func day(_ outages: [MinuteRange], unknown: [MinuteRange] = []) -> DaySchedule {
        .build(dateKey: "2026-11-12", subgroup: sg, outages: outages, unknown: unknown, source: nil, publishedAt: nil)
    }

    func testIdenticalSchedulesHaveNoDifference() {
        let a = day([.init(start: 60, end: 120)])
        XCTAssertEqual(SourceComparison.differences(a, a), [])
    }

    func testDifferencesAreMergedRanges() {
        let site = day([.init(start: 60, end: 120), .init(start: 600, end: 660)])
        let api = day([.init(start: 60, end: 150), .init(start: 600, end: 630)])
        let diff = SourceComparison.differences(site, api)
        XCTAssertEqual(diff, [.init(start: 120, end: 150), .init(start: 630, end: 660)])
        XCTAssertEqual(SourceComparison.differingMinutes(diff), 60)
    }

    func testUnknownVersusAvailableCountsAsDifference() {
        let site = day([])
        let api = day([], unknown: [.init(start: 0, end: 60)])
        XCTAssertEqual(SourceComparison.differences(site, api), [.init(start: 0, end: 60)])
    }

    func testDifferenceUntilMidnight() {
        let site = day([.init(start: 1380, end: 1440)])
        let api = day([])
        XCTAssertEqual(SourceComparison.differences(site, api), [.init(start: 1380, end: 1440)])
    }

    func testNoComparisonWhenOneSourceHasNoSchedule() {
        let site = day([.init(start: 60, end: 120)])
        let missing = DaySchedule.unknown(dateKey: "2026-11-12", subgroup: sg, kind: .notPublished)
        XCTAssertEqual(SourceComparison.differences(site, missing), [])
    }
}
