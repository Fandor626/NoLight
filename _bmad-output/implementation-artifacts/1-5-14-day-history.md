---
baseline_commit: e2cf2358ac57c232d74c943fd8eb0e1060a7c692
jira: NOL-14
branch: feature/NOL-14-14-day-history
---
# Story 1.5: 14-day history

Status: review

## Story

As Bohdan,
I want to browse previous days,
so that I can compare them with today.

## Acceptance Criteria

1. Given the app saved previous days, When I open place details, Then I can navigate to any of the last 14 days.
2. Given a day older than 14 days, When a refresh runs, Then it is removed from the cache.
3. Given a day had no data, When I open it, Then «Невідомо» is shown.

## Tasks / Subtasks

- [x] Task 1: `AppConfig.historyDays = 14`; `ScheduleService.fetchLatest` keeps posts with `dateKey >= today − 14` (was: yesterday) (AC: 2)
- [x] Task 2: `HistoryWindow` (Shared): `oldestKey`, `previousKeys` (yesterday … today−14), `pastSchedule` (missing post → `.noData`, not «not published») (AC: 1, 3)
- [x] Task 3: `PlaceDetailView`: segmented «Раніше / Сьогодні / Завтра»; «Раніше» shows a horizontal day strip (newest first); past day without data → «Невідомо» + «Для цього дня немає збереженого графіка.» (AC: 1, 3)
- [x] Task 4: `KyivTime.shortDayString` for the strip («09.11, пн»)
- [x] Task 5: Tests `HistoryTests` (window, month/year boundary, unknown past day, retention in `fetchLatest`)

## Dev Notes

- History accumulates from the update onward: the oblenergo news list only exposes recent posts, so older days are not back-filled.
- Cache shape unchanged (only more `posts` keys), so no cache version bump. 12 subgroups × 15 days stays tiny.
- NOL-13's «Сьогодні / Завтра» behaviour is unchanged; «Раніше» is added as a third segment.
- Expired-data rule (> 24 h → unknown) still applies to today/tomorrow; past days show what was saved for them.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5

### Completion Notes List

- Build and tests NOT run (no Swift toolchain/Xcode in the agent environment).

### Manual verification (Xcode)
1. Use the app for a few days (or keep the existing cache) → place details → «Раніше» → strip shows 14 days, newest first; tapping a saved day shows its timeline and intervals.
2. A day without a saved post → «Невідомо».
3. «Сьогодні» / «Завтра» behave as before.
4. ⌘U → `HistoryTests` green.

### File List
- Shared/Models/HistoryWindow.swift (new)
- Tests/HistoryTests.swift (new)
- Shared/Support/AppConfig.swift
- Shared/Data/ScheduleService.swift
- Shared/Support/KyivTime.swift
- App/PlaceDetailView.swift
- _bmad-output/implementation-artifacts/1-5-14-day-history.md (new)
- _bmad-output/implementation-artifacts/sprint-status.yaml
