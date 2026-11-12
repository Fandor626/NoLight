---
baseline_commit: df4b38794cc1d533891410daa47459fed9e27e78
jira: NOL-26
branch: feature/NOL-26-night-day-split
stacked_on: feature/NOL-25-period-statistics
---
# Story 4.2: Night and day split

Status: review

## Story

As Bohdan,
I want night and day shown separately,
so that I can judge when outages hurt more.

## Acceptance Criteria

1. Given default night bounds 00:00–06:00, When I open statistics, Then hours with and without power are split into night and day.
2. Given night bounds that cross midnight (e.g. 22:00–06:00), Then the calculation is correct.

## Tasks / Subtasks

- [x] Task 1: `NightBounds` (Shared): default 00:00–06:00, `isValid` (start ≠ end), `ranges` (one or two `MinuteRange`s when crossing midnight), `dayRanges` (complement) (AC: 1, 2)
- [x] Task 2: `StatisticsCalculator.minutes(of:within:)` intersects intervals with ranges (DST weights kept); `DayStatistics.night/daytime`; `PlaceStatistics.previousNightTotal/previousDayTotal` (AC: 1, 2)
- [x] Task 3: `StatisticsView`: «Ніч» (with bounds) and «День» rows in the period totals; today/tomorrow rows show night/day hours without power (AC: 1)
- [x] Task 4: Tests `NightDaySplitTests`

## Dev Notes

- The split is per calendar day: with 22:00–06:00 a day's night is 00:00–06:00 + 22:00–24:00 of that same day.
- Invalid bounds fall back to the default (validation UI comes in NOL-27).
- Stacked on NOL-25.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5

### Completion Notes List

- Build and tests NOT run (no Swift toolchain/Xcode in the agent environment).

### Manual verification
1. Place details → «Статистика» → totals show «Ніч 00:00–06:00» and «День»; today/tomorrow rows show night/day hours without power.
2. ⌘U → `NightDaySplitTests` and `StatisticsTests` green.

### File List
- Shared/Models/NightBounds.swift (new)
- Shared/Models/StatisticsCalculator.swift
- App/StatisticsView.swift
- Tests/NightDaySplitTests.swift (new)
- _bmad-output/implementation-artifacts/4-2-night-day-split.md (new)
- _bmad-output/implementation-artifacts/sprint-status.yaml
