---
baseline_commit: d05fc8c16e7d2c607a781ff6cae8388abff3ae97
jira: NOL-25
branch: feature/NOL-25-period-statistics
stacked_on: main
---
# Story 4.1: Statistics for a period

Status: review

## Story

As Bohdan,
I want to see hours with and without power,
so that I understand how heavy the outages are.

## Acceptance Criteria

1. Given a place with data, When I open statistics, Then I see hours with and without power for today, tomorrow (if available) and selected previous days.
2. Given a day without data, Then it is marked «Невідомо» and not included in totals.

## Tasks / Subtasks

- [x] Task 1: `StatisticsCalculator` (Shared): `PowerMinutes` (available / outage / unknown), `DayStatistics` (nil minutes = «Невідомо»), `PlaceStatistics` with totals over known previous days only (AC: 1, 2)
- [x] Task 2: DST days counted by real length (23 h / 25 h) via `dstShift`, tz-data agnostic (AC: 1)
- [x] Task 3: `StatisticsPeriod` 3 / 7 / 14 days (limited by the 14-day history, NOL-14) (AC: 1)
- [x] Task 4: `StatisticsView` sheet: «Сьогодні», «Завтра» (only if published), «Разом за N днів» with % without power and the count of days without data, «Попередні дні» list (AC: 1, 2)
- [x] Task 5: Entry points in place details: «Статистика» card (shows today's hours without power) and «…» menu item
- [x] Task 6: Tests `StatisticsTests`

## Dev Notes

- Schedules are stored as 1440 wall-clock minutes; on a DST day the skipped hour weighs 0 and the repeated hour weighs 2, so totals equal the real day length.
- Unknown minutes inside a published day are shown separately («Невідомо: …») and never added to "with power".
- Totals cover the selected previous days; today and tomorrow are shown on their own rows (they are a plan, not history).
- **Open question:** should today's row count only the elapsed part of the day? Currently it shows the whole day by the schedule.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5

### Completion Notes List

- Build and tests NOT run (no Swift toolchain/Xcode in the agent environment).

### Manual verification
1. Place details → «Статистика» card (or «…» → «Статистика») → today/tomorrow hours, period picker 3/7/14 days, totals.
2. A previous day without a saved schedule shows «Невідомо» and the footer says it is not counted.
3. ⌘U → `StatisticsTests` green.

### File List
- Shared/Models/StatisticsCalculator.swift (new)
- App/StatisticsView.swift (new)
- Tests/StatisticsTests.swift (new)
- App/PlaceDetailView.swift
- _bmad-output/implementation-artifacts/4-1-period-statistics.md (new)
- _bmad-output/implementation-artifacts/sprint-status.yaml
