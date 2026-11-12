---
baseline_commit: 4dd304a590c3a9b8dc7cdf100b2961dd166f66c9
jira: NOL-21
branch: feature/NOL-21-warning-before-outage
stacked_on: feature/NOL-18-source-comparison-screen (PR #19)
---
# Story 3.3: Warning before an outage

Status: review

## Story

As Bohdan,
I want a notification N minutes before an outage,
so that I can start the generator in time.

## Acceptance Criteria

1. Given a lead time (e.g. 15 min) for a place, When there is an upcoming outage, Then a local notification is scheduled and arrives within ±1 min.
2. Given more than 64 notifications would be needed, Then only the nearest are scheduled; the rest are scheduled on later replans.
3. Given the schedule changed or the place was deleted, Then notifications are recalculated or cancelled.

## Tasks / Subtasks

- [x] Task 1: `Place.warnBeforeOutageMinutes` (optional → old places decode; off by default), options 5/10/15/30/60, default 15 (AC: 1)
- [x] Task 2: `NotificationPlanner` (Shared, pure): outage starts from today+tomorrow, fire = start − lead, only future, nearest first, capped at 64; ids `nolight.<place>.outage.<unix>`; `diff` keeps foreign requests (AC: 1, 2, 3)
- [x] Task 3: `NotificationScheduler` (App): permission on first enable; removes stale ours, adds missing as `UNCalendarNotificationTrigger` in Europe/Kyiv (minute precision) (AC: 1, 3)
- [x] Task 4: Replan after every refresh, every place change (add/rename/move/delete/source/warning) and after the background task (AC: 2, 3)
- [x] Task 5: Place settings «Попередження»: toggle «Перед відключенням» + «За скільки» (AC: 1)
- [x] Task 6: Tests `NotificationPlannerTests`

## Dev Notes

- Deleting a place → it is not in the plan → its pending requests are removed (AC3; closes NOL-12 AC4).
- Expired/missing data → presentation is «невідомо» → nothing is planned (no false warnings).
- Delivery precision: calendar trigger at the exact minute; iOS delivers local notifications on time even when the app is not running (SM-2).
- Stacked on NOL-18 (PR #19).

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5

### Completion Notes List

- Build and tests NOT run (no Swift toolchain/Xcode in the agent environment).

### Manual verification (device)
1. Place → «…» → «Налаштування місця» → «Перед відключенням» on → allow notifications.
2. Use a schedule with an outage soon (or a test snapshot) → notification arrives at start − 15 min.
3. Delete the place → its pending notifications disappear (Settings → Notifications or a debug print of pending requests).
4. ⌘U → `NotificationPlannerTests` green.

### File List
- Shared/Models/NotificationPlanner.swift (new)
- App/NotificationScheduler.swift (new)
- Tests/NotificationPlannerTests.swift (new)
- Shared/Models/Place.swift
- App/AppState.swift
- App/BackgroundRefresh.swift
- App/PlaceSettingsView.swift
- _bmad-output/implementation-artifacts/3-3-warning-before-outage.md (new)
- _bmad-output/implementation-artifacts/sprint-status.yaml
