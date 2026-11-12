---
baseline_commit: 10e9fb9cec8a0282220aebd62f353720a2e1f70a
jira: NOL-22
branch: feature/NOL-22-warning-before-power-returns
stacked_on: feature/NOL-21-warning-before-outage (PR #20)
---
# Story 3.4: Warning before power returns

Status: review

## Story

As Bohdan,
I want a notification N minutes before power returns,
so that I can stop the generator in time.

## Acceptance Criteria

1. Given a lead time configured separately from NOL-21, When power is about to return, Then a notification is scheduled and arrives within ±1 min.
2. Given the warning is off for the place, Then no such notifications are scheduled.

## Tasks / Subtasks

- [x] Task 1: `Place.warnBeforeReturnMinutes` (optional, off by default) (AC: 1, 2)
- [x] Task 2: `NotificationPlanner` kind `.powerReturn`: outage → available transition only (not outage → unknown), own lead time, same 64-slot budget and sorting (AC: 1, 2)
- [x] Task 3: Place settings: «Перед поверненням світла» toggle + «За скільки» (AC: 1, 2)
- [x] Task 4: Tests in `NotificationPlannerTests`

## Dev Notes

- Scheduling/delivery is shared with NOL-21 (`NotificationScheduler`), so replanning, permission and cancelation on delete apply to both kinds.
- Stacked on NOL-21 (PR #20).

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5

### Completion Notes List

- Build and tests NOT run (no Swift toolchain/Xcode in the agent environment).

### Manual verification (device)
1. Place settings → «Перед поверненням світла» on, 30 хв → notification 30 min before an outage ends («…: світло о HH:MM»).
2. Turn it off → those notifications disappear; outage warnings stay.
3. ⌘U → `NotificationPlannerTests` green.

### File List
- Shared/Models/Place.swift
- Shared/Models/NotificationPlanner.swift
- App/AppState.swift
- App/PlaceSettingsView.swift
- Tests/NotificationPlannerTests.swift
- _bmad-output/implementation-artifacts/3-4-warning-before-power-returns.md (new)
- _bmad-output/implementation-artifacts/sprint-status.yaml
