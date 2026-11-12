import XCTest

final class ScheduleLogicTests: XCTestCase {
    private let day = "2026-11-10"
    private let next = "2026-11-11"

    func testBuildFillsGapsWithAvailableAndCoversWholeDay() {
        let d = DaySchedule.build(dateKey: day, subgroup: Fixtures.sg11, outages: [Fixtures.r(0, 120), Fixtures.r(240, 480)],
                                  source: nil, publishedAt: nil)
        XCTAssertEqual(d.intervals, [
            .init(start: 0, end: 120, state: .outage),
            .init(start: 120, end: 240, state: .available),
            .init(start: 240, end: 480, state: .outage),
            .init(start: 480, end: 1440, state: .available),
        ])
        XCTAssertEqual(d.intervals.reduce(0) { $0 + $1.duration }, 1440)
        XCTAssertEqual(d.state(atMinute: 119), .outage)
        XCTAssertEqual(d.state(atMinute: 120), .available)
        XCTAssertEqual(d.state(atMinute: 1439), .available)
    }

    func testFullRealDayCoversWholeDay() {
        let d = DaySchedule.build(dateKey: day, subgroup: Fixtures.sg11, outages: Fixtures.outages11, source: nil, publishedAt: nil)
        XCTAssertEqual(d.intervals.reduce(0) { $0 + $1.duration }, 1440)
        XCTAssertEqual(d.outageIntervals.count, 5)
    }

    func testInvalidRangesAreDropped() {
        let n = MinuteRange.normalized([Fixtures.r(500, 400), Fixtures.r(-5, 10), Fixtures.r(0, 1500), Fixtures.r(10, 20)])
        XCTAssertEqual(n, [Fixtures.r(10, 20)])
    }

    private func realSnapshot() -> ScheduleSnapshot {
        Fixtures.snapshot(posts: [day: ["1.1": Fixtures.outages11]], fetchedAt: Fixtures.kyiv(2026, 11, 10, 12, 0))
    }

    private func status(_ s: ScheduleSnapshot, _ sg: Subgroup, at now: Date) -> SubgroupPresentation {
        SubgroupPresentation(snapshot: s, subgroup: sg, now: now)
    }

    func testStatusDuringOutage() {
        let p = status(realSnapshot(), Fixtures.sg11, at: Fixtures.kyiv(2026, 11, 10, 13, 0))
        XCTAssertEqual(p.status.state, .outage)
        XCTAssertEqual(p.status.changeAt, Fixtures.kyiv(2026, 11, 10, 14, 0))
        XCTAssertEqual(p.status.nextState, .available)
        XCTAssertEqual(p.headline, "Світла немає")
        XCTAssertEqual(p.detail, "Світло з’явиться о 14:00")
    }

    func testStatusWhenAvailable() {
        let p = status(realSnapshot(), Fixtures.sg11, at: Fixtures.kyiv(2026, 11, 10, 14, 30))
        XCTAssertEqual(p.status.state, .available)
        XCTAssertEqual(p.status.changeAt, Fixtures.kyiv(2026, 11, 10, 16, 0))
        XCTAssertEqual(p.detail, "Відключення о 16:00")
    }

    func testStatusExactlyAtBoundaryBelongsToNewInterval() {
        let p = status(realSnapshot(), Fixtures.sg11, at: Fixtures.kyiv(2026, 11, 10, 14, 0))
        XCTAssertEqual(p.status.state, .available)
    }

    func testTomorrowUnpublishedMakesEndOfDayUnknownNotAvailable() {
        let p = status(realSnapshot(), Fixtures.sg11, at: Fixtures.kyiv(2026, 11, 10, 23, 30))
        XCTAssertEqual(p.status.state, .outage)
        XCTAssertEqual(p.status.changeAt, Fixtures.kyiv(2026, 11, 11, 0, 0))
        XCTAssertEqual(p.status.nextState, .unknown)
        XCTAssertEqual(p.detail, "Графік після 24:00 невідомий")
    }

    func testOutageSpanningMidnightAcrossTwoDays() {
        let s = Fixtures.snapshot(posts: [day: ["1.1": [Fixtures.r(1380, 1440)]], next: ["1.1": [Fixtures.r(0, 120)]]],
                                  fetchedAt: Fixtures.kyiv(2026, 11, 10, 20, 0))
        let p = status(s, Fixtures.sg11, at: Fixtures.kyiv(2026, 11, 10, 23, 30))
        XCTAssertEqual(p.status.state, .outage)
        XCTAssertEqual(p.status.changeAt, Fixtures.kyiv(2026, 11, 11, 2, 0))
        XCTAssertEqual(p.status.nextState, .available)
    }

    func testSpilloverFromPreviousDayAppliesToNextDay() {
        let s = Fixtures.snapshot(posts: [day: ["2.1": [Fixtures.r(1320, 1440)]], next: ["2.1": [Fixtures.r(600, 660)]]],
                                  spillover: [day: ["2.1": [Fixtures.r(0, 120)]]],
                                  fetchedAt: Fixtures.kyiv(2026, 11, 10, 20, 0))
        let d = s.schedule(for: Fixtures.sg21, dateKey: next)
        XCTAssertEqual(d.intervals.first, .init(start: 0, end: 120, state: .outage))
        XCTAssertEqual(d.state(atMinute: 600), .outage)
    }

    // NOL-13: «Завтра» без графіка показує повідомлення, а не порожню шкалу.
    func testTomorrowNotPublishedHasPlaceholderInsteadOfTimeline() {
        let p = status(realSnapshot(), Fixtures.sg11, at: Fixtures.kyiv(2026, 11, 10, 12, 0))
        XCTAssertEqual(p.tomorrow.kind, .notPublished)
        XCTAssertEqual(p.tomorrow.kind.placeholderTitle, "Графік ще не опублікований")
        XCTAssertNotNil(p.tomorrow.kind.placeholderMessage)
        XCTAssertNil(p.today.kind.placeholderTitle)
        XCTAssertNil(DayScheduleKind.published.placeholderMessage)
    }

    // NOL-13: інтервал через північ видно на обох добах.
    func testMidnightCrossingOutageVisibleOnBothDays() {
        let s = Fixtures.snapshot(posts: [day: ["1.1": [Fixtures.r(1380, 1440)]], next: ["1.1": [Fixtures.r(0, 120)]]],
                                  fetchedAt: Fixtures.kyiv(2026, 11, 10, 20, 0))
        let p = status(s, Fixtures.sg11, at: Fixtures.kyiv(2026, 11, 10, 21, 0))
        XCTAssertEqual(p.today.intervals.last, .init(start: 1380, end: 1440, state: .outage))
        XCTAssertEqual(p.tomorrow.intervals.first, .init(start: 0, end: 120, state: .outage))
    }

    func testNotPublishedDayIsUnknownNeverAvailable() {
        let s = Fixtures.snapshot(posts: [next: ["1.1": Fixtures.outages11]], fetchedAt: Fixtures.kyiv(2026, 11, 10, 11, 0))
        let p = status(s, Fixtures.sg11, at: Fixtures.kyiv(2026, 11, 10, 12, 0))
        XCTAssertEqual(p.today.kind, .notPublished)
        XCTAssertEqual(p.status.state, .unknown)
        XCTAssertEqual(p.headline, "Графік не опубліковано")
    }

    func testSubgroupMissingFromPublishedPostIsUnknown() {
        let p = status(realSnapshot(), Fixtures.sg22, at: Fixtures.kyiv(2026, 11, 10, 12, 0))
        XCTAssertEqual(p.today.kind, .subgroupNotListed)
        XCTAssertEqual(p.status.state, .unknown)
    }

    func testProblemDateIsReportedAsParseFailedEvenIfOldPostExists() {
        let base = realSnapshot()
        let s = ScheduleSnapshot(fetchedAt: base.fetchedAt, posts: base.posts, problemDates: [day])
        let p = status(s, Fixtures.sg11, at: Fixtures.kyiv(2026, 11, 10, 13, 0))
        XCTAssertEqual(p.today.kind, .parseFailed)
        XCTAssertEqual(p.status.state, .unknown)
    }

    func testNoSnapshotMeansNoData() {
        let p = SubgroupPresentation(snapshot: nil, subgroup: Fixtures.sg11, now: Fixtures.kyiv(2026, 11, 10, 12, 0))
        XCTAssertEqual(p.reliability, .none)
        XCTAssertEqual(p.status.state, .unknown)
        XCTAssertEqual(p.headline, "Даних ще немає")
    }

    func testReliabilityThresholds() {
        let now = Fixtures.kyiv(2026, 11, 10, 12, 0)
        // NOL-31 / PRD FR-9: «застаріло» після 1 години.
        XCTAssertEqual(StatusCalculator.reliability(fetchedAt: now.addingTimeInterval(-59 * 60), now: now), .fresh)
        XCTAssertEqual(StatusCalculator.reliability(fetchedAt: now.addingTimeInterval(-3600), now: now), .stale)
        XCTAssertEqual(StatusCalculator.reliability(fetchedAt: now.addingTimeInterval(-5 * 3600), now: now), .stale)
        XCTAssertEqual(StatusCalculator.reliability(fetchedAt: now.addingTimeInterval(-25 * 3600), now: now), .expired)
        XCTAssertEqual(StatusCalculator.reliability(fetchedAt: nil, now: now), .none)
    }

    func testExpiredDataIsNotShownAsCurrent() {
        let p = status(realSnapshot(), Fixtures.sg11, at: Fixtures.kyiv(2026, 11, 11, 13, 0))
        XCTAssertEqual(p.reliability, .expired)
        XCTAssertEqual(p.status.state, .unknown)
        XCTAssertEqual(p.today.kind, .noData)
    }

    func testStaleDataStillShownButFlagged() {
        let p = status(realSnapshot(), Fixtures.sg11, at: Fixtures.kyiv(2026, 11, 10, 18, 30))
        XCTAssertEqual(p.reliability, .stale)
        XCTAssertTrue(p.showsStaleWarning)
        XCTAssertNotEqual(p.status.state, .unknown)
    }

    func testTimelineGeometry() {
        XCTAssertEqual(TimelineGeometry.fraction(minute: 720), 0.5, accuracy: 1e-9)
        XCTAssertEqual(TimelineGeometry.markerX(minute: 14 * 60 + 30, width: 288), 174, accuracy: 1e-9)
        XCTAssertEqual(TimelineGeometry.markerX(minute: -10, width: 288), 0)
        XCTAssertEqual(TimelineGeometry.markerX(minute: 5000, width: 288), 288)
        XCTAssertEqual(TimelineGeometry.clampedLabelCenter(x: 2, labelWidth: 34, containerWidth: 288), 17)
        XCTAssertEqual(TimelineGeometry.clampedLabelCenter(x: 287, labelWidth: 34, containerWidth: 288), 271)
        XCTAssertEqual(TimelineGeometry.clampedLabelCenter(x: 100, labelWidth: 34, containerWidth: 288), 100)
    }

    func testSegmentFramesCoverFullWidth() {
        let d = DaySchedule.build(dateKey: day, subgroup: Fixtures.sg11, outages: Fixtures.outages11, source: nil, publishedAt: nil)
        let frames = TimelineGeometry.segmentFrames(d.intervals, width: 288)
        XCTAssertEqual(frames.reduce(0) { $0 + $1.width }, 288, accuracy: 1e-6)
        XCTAssertEqual(frames.first?.x, 0)
    }

    func testKyivMinutesUseKyivTimeZone() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let d = utc.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 12, minute: 0))!
        XCTAssertEqual(KyivTime.minutes(of: d), 14 * 60)
        XCTAssertEqual(KyivTime.dateKey(for: d), "2026-11-10")
    }

    func testWidgetEntryDates() {
        let now = Fixtures.kyiv(2026, 11, 10, 14, 30)
        let fetched = Fixtures.kyiv(2026, 11, 10, 14, 0)
        let s = Fixtures.snapshot(posts: [day: ["1.1": Fixtures.outages11]], fetchedAt: fetched)
        let dates = WidgetTimelinePlanner.entryDates(now: now, snapshot: s, subgroup: Fixtures.sg11)

        XCTAssertEqual(dates.first, now)
        XCTAssertEqual(dates, dates.sorted())
        XCTAssertEqual(Set(dates).count, dates.count)
        XCTAssertTrue(dates.allSatisfy { $0 <= now.addingTimeInterval(24 * 3600) })
        XCTAssertTrue(dates.contains(Fixtures.kyiv(2026, 11, 10, 16, 0)))
        XCTAssertTrue(dates.contains(Fixtures.kyiv(2026, 11, 10, 14, 45)))
        XCTAssertTrue(dates.contains(Fixtures.kyiv(2026, 11, 11, 0, 0)))
        XCTAssertTrue(dates.contains(fetched.addingTimeInterval(AppConfig.staleAfter)))
        XCTAssertTrue(dates.contains(fetched.addingTimeInterval(AppConfig.expiredAfter)))
    }
}
