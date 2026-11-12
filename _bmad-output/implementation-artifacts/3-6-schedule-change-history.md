---
baseline_commit: c977b70c8c10071b84bc391d6011b23fc741799e
jira: NOL-24
branch: feature/NOL-24-schedule-change-history
stacked_on: feature/NOL-23-schedule-change-notification (PR #22)
---
# Story 3.6: Schedule change history

Status: review

## Story

As Bohdan,
I want to see how a schedule changed,
so that I can compare the old and new timetable.

## Acceptance Criteria

1. Given a change was recorded, When I open the place history, Then I see when it changed and the old and new intervals.
2. Given an entry older than 14 days, Then it is removed.

## Tasks / Subtasks

- [x] Task 1: `ScheduleChangeHistory.merged` (Shared): newest first, drops entries older than 14 days and of deleted places (AC: 2)
- [x] Task 2: `ScheduleChangeHistoryStore` (App Group); `ScheduleChangeNotifier.process` records every detected change (also when notifications are off) and prunes on each run (AC: 1, 2)
- [x] Task 3: `AppState.changeHistory` + place details card «Зміни графіка»: detection time, which day, «Було» (struck through) / «Стало» (AC: 1)
- [x] Task 4: Tests `ScheduleChangeHistoryTests`

## Dev Notes

- History is fed by the same detector as NOL-23, so it fills in from the app and from the background task.
- The card appears only when the place has at least one change.
- Stacked on NOL-23 (PR #22).

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5

### Completion Notes List

- Build and tests NOT run (no Swift toolchain/Xcode in the agent environment).

### Manual verification
1. After a schedule change was detected (NOL-23) → place details → «Зміни графіка» shows time, day, «Було» / «Стало».
2. ⌘U → `ScheduleChangeHistoryTests` green.

### File List
- Shared/Data/ScheduleChangeHistory.swift (new)
- Tests/ScheduleChangeHistoryTests.swift (new)
- App/ScheduleChangeNotifier.swift
- App/AppState.swift
- App/PlaceDetailView.swift
- _bmad-output/implementation-artifacts/3-6-schedule-change-history.md (new)
- _bmad-output/implementation-artifacts/sprint-status.yaml
