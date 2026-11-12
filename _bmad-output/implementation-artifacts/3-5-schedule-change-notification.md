---
baseline_commit: d8344f1758c8b06175b7407f5c31fb32caa3f2b6
jira: NOL-23
branch: feature/NOL-23-schedule-change-notification
stacked_on: feature/NOL-22-warning-before-power-returns (PR #21)
---
# Story 3.5: Schedule change notification

Status: review

## Story

As Bohdan,
I want a notification when my place's schedule changes,
so that I can rearrange my plans.

## Acceptance Criteria

1. Given a refresh detects changed intervals for a place, When the refresh finishes, Then a notification «Графік для «{name}» змінився» with a short summary is delivered.
2. Given no changes, Then no notification is sent.
3. Given delivery depends on iOS background runs, Then settings say the notification may arrive late.

## Tasks / Subtasks

- [x] Task 1: `ScheduleChangeDetector` (Shared, pure): compares today/tomorrow with the last seen intervals; first sight (incl. newly published tomorrow) is not a change; prunes old days and deleted places; summary text (AC: 1, 2)
- [x] Task 2: `ScheduleSeenStore` (App Group) so changes are noticed whoever refreshed the cache (app, widget, background) (AC: 1)
- [x] Task 3: `ScheduleChangeNotifier`: immediate notification «Графік для «…» змінився» + «Сьогодні: відключення … (було: …)»; separate id prefix so warning replans never remove it (AC: 1)
- [x] Task 4: Runs after every app refresh and after the background task, before warnings are replanned; switching a place's source resets its seen schedule (no false "change") (AC: 1)
- [x] Task 5: Place settings: «Про зміну графіка» toggle; footer explains possible delay (AC: 3)
- [x] Task 6: Tests `ScheduleChangeTests`

## Dev Notes

- **Open question resolved:** the first publication of tomorrow is not a change.
- Per-place toggle, off by default — consistent with the other warnings and the notification permission prompt.
- `process` returns the detected changes; NOL-24 stores them as history.
- Stacked on NOL-22 (PR #21).

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5

### Completion Notes List

- Build and tests NOT run (no Swift toolchain/Xcode in the agent environment).

### Manual verification (device)
1. Place settings → «Про зміну графіка» on.
2. When oblenergo publishes an updated post for today → after refresh a notification «Графік для «…» змінився» with the new/old intervals.
3. Refresh without changes → no notification.
4. ⌘U → `ScheduleChangeTests` green.

### File List
- Shared/Models/ScheduleChanges.swift (new)
- Shared/Data/ScheduleSeenStore.swift (new)
- App/ScheduleChangeNotifier.swift (new)
- Tests/ScheduleChangeTests.swift (new)
- Shared/Models/Place.swift
- App/AppState.swift
- App/BackgroundRefresh.swift
- App/PlaceSettingsView.swift
- _bmad-output/implementation-artifacts/3-5-schedule-change-notification.md (new)
- _bmad-output/implementation-artifacts/sprint-status.yaml
